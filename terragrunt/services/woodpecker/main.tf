locals {
  argocd_namespace = "argocd"
  namespace        = "woodpecker"
  hostname         = "${var.subdomain}.${var.domain}"
  woodpecker_url   = "https://${local.hostname}"

  forgejo_oauth_name         = "woodpecker"
  forgejo_oauth_redirect_uri = "${local.woodpecker_url}/authorize"

  agent_secret_checksum         = sha256(random_password.agent_secret.result)
  forgejo_oauth_secret_checksum = sha256(gitea_oauth2_app.woodpecker.client_secret)

  base_values = yamldecode(var.woodpecker_values_yaml)

  patched_server = merge(local.base_values.server, {
    podAnnotations = merge(try(local.base_values.server.podAnnotations, {}), {
      "checksum/woodpecker-secret" = sha256("${local.agent_secret_checksum}:${local.forgejo_oauth_secret_checksum}")
    })
  })

  patched_agent = merge(local.base_values.agent, {
    podAnnotations = merge(try(local.base_values.agent.podAnnotations, {}), {
      "checksum/woodpecker-secret" = local.agent_secret_checksum
    })
  })

  helm_values = yamlencode(merge(local.base_values, {
    server = local.patched_server
    agent  = local.patched_agent
  }))

  # `var.platform_data_ready` and `var.forgejo_ready` may come from either
  # Terragrunt dependencies or a parent Terraform module. Keep them in the
  # Terraform graph so Woodpecker only talks to Forgejo after Forgejo is ready.
}

resource "terraform_data" "platform_data_gate" {
  input = var.platform_data_ready
}

resource "terraform_data" "forgejo_gate" {
  input = var.forgejo_ready
}

resource "kubernetes_namespace" "woodpecker" {
  metadata {
    name = local.namespace
    labels = {
      "managed-by" = "terragrunt"
    }
  }
}

data "kubernetes_secret" "forgejo_admin" {
  metadata {
    name      = "forgejo-admin"
    namespace = var.forgejo_namespace
  }

  depends_on = [terraform_data.forgejo_gate]
}

resource "random_password" "agent_secret" {
  length  = 64
  special = false
}

resource "gitea_oauth2_app" "woodpecker" {
  name                = local.forgejo_oauth_name
  redirect_uris       = [local.forgejo_oauth_redirect_uri]
  confidential_client = true

  depends_on = [terraform_data.forgejo_gate]
}

resource "kubernetes_secret" "woodpecker" {
  metadata {
    name      = "woodpecker-secrets"
    namespace = kubernetes_namespace.woodpecker.metadata[0].name
  }

  data = {
    WOODPECKER_AGENT_SECRET   = random_password.agent_secret.result
    WOODPECKER_FORGEJO_CLIENT = gitea_oauth2_app.woodpecker.client_id
    WOODPECKER_FORGEJO_SECRET = gitea_oauth2_app.woodpecker.client_secret
  }
}

resource "kubectl_manifest" "argo_app_woodpecker" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "woodpecker"
      namespace = local.argocd_namespace
    }
    spec = {
      project = "platform"
      source = {
        repoURL        = "ghcr.io/woodpecker-ci/helm"
        chart          = "woodpecker"
        targetRevision = var.woodpecker_chart_version
        helm = {
          releaseName = "woodpecker"
          values      = local.helm_values
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.woodpecker.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "ServerSideApply=true",
          "CreateNamespace=false",
        ]
      }
    }
  })

  depends_on = [
    terraform_data.platform_data_gate,
    kubernetes_secret.woodpecker,
  ]
}

resource "kubectl_manifest" "httproute_woodpecker" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "woodpecker"
      namespace = kubernetes_namespace.woodpecker.metadata[0].name
    }
    spec = {
      parentRefs = [
        {
          group     = "gateway.networking.k8s.io"
          kind      = "Gateway"
          name      = var.gateway_name
          namespace = var.gateway_namespace
        }
      ]
      hostnames = [local.hostname]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          backendRefs = [
            {
              name = "woodpecker-server"
              port = 80
            }
          ]
        }
      ]
    }
  })

  depends_on = [
    kubectl_manifest.argo_app_woodpecker,
  ]
}

resource "terraform_data" "woodpecker_ready" {
  triggers_replace = [
    kubectl_manifest.argo_app_woodpecker.uid,
    kubectl_manifest.httproute_woodpecker.uid,
  ]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      set -euo pipefail
      kubectl wait --for=jsonpath='{.status.sync.status}'=Synced \
        application/woodpecker -n ${local.argocd_namespace} --timeout=10m
      kubectl -n ${kubernetes_namespace.woodpecker.metadata[0].name} \
        rollout status statefulset/woodpecker-server --timeout=10m
      kubectl -n ${kubernetes_namespace.woodpecker.metadata[0].name} \
        rollout status statefulset/woodpecker-agent --timeout=10m
      kubectl -n ${kubernetes_namespace.woodpecker.metadata[0].name} \
        wait --for=jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'=True \
        httproute/woodpecker --timeout=5m
      kubectl wait --for=jsonpath='{.status.health.status}'=Healthy \
        application/woodpecker -n ${local.argocd_namespace} --timeout=5m
    EOT
  }
}
