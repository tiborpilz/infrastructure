locals {
  apiserver_url_no_scheme = trimprefix(var.kubernetes_host, "https://")
  apiserver_host          = split(":", local.apiserver_url_no_scheme)[0]
}

data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_version}/standard-install.yaml"

  request_headers = {
    Accept = "text/plain"
  }
}

data "kubectl_file_documents" "gateway_api_crds" {
  content = data.http.gateway_api_crds.response_body
}

resource "kubectl_manifest" "gateway_api_crds" {
  for_each = data.kubectl_file_documents.gateway_api_crds.manifests

  yaml_body         = each.value
  server_side_apply = true
}

resource "kubernetes_secret" "hcloud" {
  metadata {
    name      = "hcloud"
    namespace = "kube-system"
  }

  data = {
    token   = var.hcloud_token
    network = var.hcloud_network_id
  }
}

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.cilium_chart_version
  namespace  = "kube-system"

  values = [yamlencode({
    kubeProxyReplacement = "true"
    k8sServiceHost       = local.apiserver_host
    k8sServicePort       = 6443

    ipam = {
      mode = "kubernetes"
    }

    securityContext = {
      capabilities = {
        ciliumAgent = [
          "CHOWN",
          "KILL",
          "NET_ADMIN",
          "NET_RAW",
          "IPC_LOCK",
          "SYS_ADMIN",
          "SYS_RESOURCE",
          "DAC_OVERRIDE",
          "FOWNER",
          "SETGID",
          "SETUID",
        ]
        cleanCiliumState = [
          "NET_ADMIN",
          "SYS_ADMIN",
          "SYS_RESOURCE",
        ]
      }
    }


    cgroup = {
      autoMount = { enabled = false }
      hostRoot  = "/sys/fs/cgroup"
    }

    hubble = {
      relay = { enabled = true }
      ui    = { enabled = true }
    }

    gatewayAPI = {
      enabled      = true
      gatewayClass = { create = "true" }
    }

    operator = {
      replicas = 1
    }
  })]

  timeout = 600

  depends_on = [
    kubernetes_secret.hcloud,
    kubectl_manifest.gateway_api_crds,
  ]
}

resource "helm_release" "hcloud_ccm" {
  name       = "hcloud-cloud-controller-manager"
  repository = "https://charts.hetzner.cloud"
  chart      = "hcloud-cloud-controller-manager"
  version    = var.hcloud_ccm_chart_version
  namespace  = "kube-system"

  values = [yamlencode({
    networking = {
      enabled     = true
      clusterCIDR = var.pod_cidr
    }
    strategy = { type = "Recreate" }
  })]

  timeout = 300

  depends_on = [helm_release.cilium]
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "managed-by" = "terragrunt"
    }
  }

  depends_on = [helm_release.hcloud_ccm]
}

resource "random_password" "argocd_oidc_client_secret" {
  length  = 48
  special = false
}

locals {
  argocd_url               = "https://${var.argocd_subdomain}.${var.domain}"
  argocd_oidc_redirect_uri = "${local.argocd_url}/auth/callback"

  argocd_oidc_config = yamlencode({
    name           = "authentik"
    issuer         = "https://auth.${var.domain}/application/o/argocd/"
    clientID       = "argocd"
    clientSecret   = "$oidc.argocd.clientSecret"
    requestedScopes = ["openid", "profile", "email", "groups"]
  })
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [yamlencode({
    server = {
      service = { type = "ClusterIP" }
      extraArgs = ["--insecure"]
    }

    configs = {
      cm = {
        "url"            = local.argocd_url
        "oidc.config"    = local.argocd_oidc_config
        "admin.enabled"  = "false"
      }

      secret = {
        extra = {
          "oidc.argocd.clientSecret" = random_password.argocd_oidc_client_secret.result
        }
      }

      rbac = {
        "policy.csv"     = "g, platform-admins, role:admin"
        "policy.default" = "role:readonly"
        "scopes" = "[groups]"
      }
    }
  })]

  timeout = 600
}

locals {
  appprojects = {
    platform = {
      description = "Core platform components managed by Terraform/Terragrunt."
      destinations = [{
        namespace = "*"
        server    = "https://kubernetes.default.svc"
      }]
      clusterResourceWhitelist = [
        { group = "*", kind = "*" }
      ]
      namespaceResourceWhitelist = [
        { group = "*", kind = "*" }
      ]
    }

    projects = {
      description = "Side-project apps. Restricted namespaces and resource kinds."
      destinations = [{
        namespace = "projects-*"
        server    = "https://kubernetes.default.svc"
      }]
      clusterResourceWhitelist = []
      namespaceResourceWhitelist = [
        { group = "", kind = "ConfigMap" },
        { group = "", kind = "Secret" },
        { group = "", kind = "Service" },
        { group = "", kind = "ServiceAccount" },
        { group = "apps", kind = "Deployment" },
        { group = "apps", kind = "StatefulSet" },
        { group = "batch", kind = "Job" },
        { group = "batch", kind = "CronJob" },
        { group = "gateway.networking.k8s.io", kind = "HTTPRoute" },
      ]
    }

    sandbox = {
      description = "Throwaway stuff."
      destinations = [{
        namespace = "sandbox-*"
        server    = "https://kubernetes.default.svc"
      }]
      clusterResourceWhitelist = []
      namespaceResourceWhitelist = [
        { group = "", kind = "ConfigMap" },
        { group = "", kind = "Service" },
        { group = "apps", kind = "Deployment" },
      ]
    }
  }
}

resource "terraform_data" "wait_for_argocd_crds" {
  triggers_replace = {
    chart_version = var.argocd_chart_version
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      set -euo pipefail
      for i in $(seq 1 60); do
        if kubectl get crd applications.argoproj.io >/dev/null 2>&1 \
           && kubectl get crd appprojects.argoproj.io >/dev/null 2>&1; then
          # Ensure the API endpoint is actually being served (CRD established
          # doesn't always mean discovery has refreshed).
          if kubectl get applications.argoproj.io -A >/dev/null 2>&1 \
             && kubectl get appprojects.argoproj.io -A >/dev/null 2>&1; then
            echo "Argo CD CRDs ready and served"
            exit 0
          fi
        fi
        echo "waiting for Argo CD CRDs (attempt $i/60)..."
        sleep 5
      done
      echo "Argo CD CRDs never became ready" >&2
      exit 1
    EOT
  }

  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "appproject" {
  for_each = local.appprojects

  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = each.key
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = merge(
      {
        sourceRepos = ["*"]
      },
      each.value,
    )
  })

  depends_on = [terraform_data.wait_for_argocd_crds]
}
