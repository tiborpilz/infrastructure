locals {
  argocd_namespace = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata   = { name = "argocd" }
  }

  argocd_age_keys_secret = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata   = { name = "age-keys", namespace = "argocd" }
    data       = { "keys.txt" = base64encode(var.argocd_age_key) }
  }

  # ArgoCD uses the HOME env var to locate age keys. Mount the secret at
  # /home/argocd/.age/keys.txt and set HOME=/home/argocd so SOPS finds it.
  argocd_repo_server_patch = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata   = { name = "argocd-repo-server", namespace = "argocd" }
    spec = {
      template = {
        spec = {
          containers = [
            {
              name = "argocd-repo-server"
              env = [
                { name = "HOME", value = "/home/argocd" }
              ]
              volumeMounts = [
                {
                  name      = "age-keys"
                  mountPath = "/home/argocd/.age"
                }
              ]
            }
          ]
          volumes = [
            {
              name = "age-keys"
              secret = {
                secretName = "age-keys"
                items = [
                  {
                    key  = "keys.txt"
                    path = "keys.txt"
                  }
                ]
              }
            }
          ]
        }
      }
    }
  }

  argocd_httproute = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata   = { name = "argocd", namespace = "argocd" }
    spec = {
      parentRefs = [{ name = "public", namespace = "gateway-system", sectionName = "https" }]
      hostnames  = ["argocd.${var.domain}"]
      rules = [{
        backendRefs = [{ name = "argocd-server", port = 80 }]
      }]
    }
  }

  argocd_manifests = [
    { name = "ns-argocd", contents = yamlencode(local.argocd_namespace) },
    { name = "argocd", contents = data.helm_template.argocd.manifest },
    { name = "argocd-age-keys-secret", contents = yamlencode(local.argocd_age_keys_secret) },
    { name = "argocd-repo-server-patch", contents = yamlencode(local.argocd_repo_server_patch) },
    { name = "argocd-httproute", contents = yamlencode(local.argocd_httproute) },
  ]
}

data "helm_template" "argocd" {
  name         = "argocd"
  namespace    = "argocd"
  repository   = "https://argoproj.github.io/argo-helm"
  chart        = "argo-cd"
  version      = var.argocd_chart_version
  kube_version = var.kubernetes_version

  set {
    name  = "server.insecure"
    value = "true"
  }

  # Without this, argocd-cm bootstraps with the chart default url
  # (argocd.example.com). The self-managed Application later corrects it, but
  # any OIDC attempt before that first sync fails with "Invalid redirect URL".
  set {
    name  = "configs.cm.url"
    value = "https://argocd.${var.domain}"
  }
}
