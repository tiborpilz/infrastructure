locals {
  argocd_namespace = "argocd"
  namespace        = "forgejo"
  hostname         = "${var.subdomain}.${var.domain}"
  forgejo_url      = "https://${local.hostname}"

  oidc_application_slug = "forgejo"
  oidc_source_name      = "authentik"
  oidc_client_id        = "forgejo"
  oidc_redirect_uri     = "${local.forgejo_url}/user/oauth2/${local.oidc_source_name}/callback"
  oidc_discovery_url    = "${var.authentik_url}/application/o/${local.oidc_application_slug}/.well-known/openid-configuration"

  admin_secret_checksum = sha256(random_password.forgejo_admin_password.result)
  oidc_secret_checksum  = sha256(random_password.forgejo_oidc_client_secret.result)

  base_values = yamldecode(var.forgejo_values_yaml)

  patched_gitea = merge(local.base_values.gitea, {
    podAnnotations = merge(try(local.base_values.gitea.podAnnotations, {}), {
      "checksum/forgejo-admin-secret" = local.admin_secret_checksum
      "checksum/forgejo-oidc-secret"  = local.oidc_secret_checksum
    })
  })

  helm_values = yamlencode(merge(local.base_values, {
    gitea       = local.patched_gitea
    extraDeploy = [yamldecode(var.database_yaml)]
  }))

  # These readiness values may come from either Terragrunt dependencies or a
  # parent Terraform module. Keep them in the Terraform graph so Forgejo's
  # CNPG Cluster and authentik provider objects are not applied before their
  # backing controllers/APIs are ready.
}

resource "terraform_data" "platform_data_gate" {
  input = var.platform_data_ready
}

resource "terraform_data" "authentik_gate" {
  input = var.authentik_ready
}

resource "terraform_data" "authentik_config_gate" {
  input = var.authentik_config_ready
}

resource "kubernetes_namespace" "forgejo" {
  metadata {
    name = local.namespace
    labels = {
      "managed-by" = "terragrunt"
    }
  }
}

resource "random_password" "forgejo_admin_password" {
  length  = 32
  special = false
}

resource "random_password" "forgejo_oidc_client_secret" {
  length  = 48
  special = false
}

resource "kubernetes_secret" "forgejo_admin" {
  metadata {
    name      = "forgejo-admin"
    namespace = kubernetes_namespace.forgejo.metadata[0].name
  }

  data = {
    username = "forgejo_admin"
    password = random_password.forgejo_admin_password.result
  }
}

resource "kubernetes_secret" "forgejo_oidc" {
  metadata {
    name      = "forgejo-oidc"
    namespace = kubernetes_namespace.forgejo.metadata[0].name
  }

  data = {
    key    = local.oidc_client_id
    secret = random_password.forgejo_oidc_client_secret.result
  }
}

data "authentik_flow" "default_authorization" {
  slug = "default-provider-authorization-implicit-consent"

  depends_on = [terraform_data.authentik_gate]
}

data "authentik_flow" "default_authentication" {
  slug = "default-authentication-flow"

  depends_on = [terraform_data.authentik_gate]
}

data "authentik_flow" "default_invalidation" {
  slug = "default-provider-invalidation-flow"

  depends_on = [terraform_data.authentik_gate]
}

data "authentik_certificate_key_pair" "default" {
  name = "authentik Self-signed Certificate"

  depends_on = [terraform_data.authentik_gate]
}

data "authentik_property_mapping_provider_scope" "openid" {
  name = "authentik default OAuth Mapping: OpenID 'openid'"

  depends_on = [terraform_data.authentik_gate]
}

data "authentik_property_mapping_provider_scope" "profile" {
  name = "authentik default OAuth Mapping: OpenID 'profile'"

  depends_on = [terraform_data.authentik_gate]
}

data "authentik_property_mapping_provider_scope" "email" {
  name = "authentik default OAuth Mapping: OpenID 'email'"

  depends_on = [terraform_data.authentik_gate]
}

resource "authentik_provider_oauth2" "forgejo" {
  name          = "forgejo"
  client_id     = local.oidc_client_id
  client_secret = random_password.forgejo_oidc_client_secret.result

  authorization_flow  = data.authentik_flow.default_authorization.id
  authentication_flow = data.authentik_flow.default_authentication.id
  invalidation_flow   = data.authentik_flow.default_invalidation.id

  signing_key = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = local.oidc_redirect_uri
    },
  ]

  property_mappings = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.profile.id,
    data.authentik_property_mapping_provider_scope.email.id,
  ]

  sub_mode = "hashed_user_id"
}

resource "authentik_application" "forgejo" {
  name              = "Forgejo"
  slug              = local.oidc_application_slug
  protocol_provider = authentik_provider_oauth2.forgejo.id
  meta_launch_url   = local.forgejo_url
}

resource "kubectl_manifest" "argo_app_forgejo" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "forgejo"
      namespace = local.argocd_namespace
    }
    spec = {
      project = "platform"
      source = {
        repoURL        = "code.forgejo.org/forgejo-helm"
        chart          = "forgejo"
        targetRevision = var.forgejo_chart_version
        helm = {
          releaseName = "forgejo"
          values      = local.helm_values
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.forgejo.metadata[0].name
      }
      ignoreDifferences = [
        {
          group     = "gateway.networking.k8s.io"
          kind      = "HTTPRoute"
          name      = "forgejo"
          namespace = kubernetes_namespace.forgejo.metadata[0].name
          jsonPointers = [
            "/spec/rules/0/backendRefs/0/group",
            "/spec/rules/0/backendRefs/0/weight",
          ]
        }
      ]
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "ServerSideApply=true",
          "CreateNamespace=false",
          "RespectIgnoreDifferences=true",
        ]
      }
    }
  })

  depends_on = [
    terraform_data.authentik_gate,
    terraform_data.authentik_config_gate,
    authentik_application.forgejo,
    kubernetes_secret.forgejo_admin,
    kubernetes_secret.forgejo_oidc,
    terraform_data.platform_data_gate,
  ]
}

resource "terraform_data" "forgejo_ready" {
  triggers_replace = [
    kubectl_manifest.argo_app_forgejo.uid,
  ]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      set -euo pipefail
      kubectl wait --for=jsonpath='{.status.sync.status}'=Synced \
        application/forgejo -n ${local.argocd_namespace} --timeout=10m
      kubectl -n ${kubernetes_namespace.forgejo.metadata[0].name} \
        wait --for=condition=Ready clusters.postgresql.cnpg.io/forgejo-db --timeout=20m
      kubectl -n ${kubernetes_namespace.forgejo.metadata[0].name} \
        wait --for=condition=Available deployment/forgejo --timeout=20m
      kubectl -n ${kubernetes_namespace.forgejo.metadata[0].name} \
        wait --for=jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'=True \
        httproute/forgejo --timeout=5m
      kubectl wait --for=jsonpath='{.status.health.status}'=Healthy \
        application/forgejo -n ${local.argocd_namespace} --timeout=5m
    EOT
  }
}
