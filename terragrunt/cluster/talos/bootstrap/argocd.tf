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

  # The platform AppProject and root Application (app-of-apps entrypoint) are
  # applied here so a fresh cluster starts syncing without any manual
  # `kubectl apply`. Talos re-applies inline manifests on change but never
  # deletes them; removals need a manual kubectl delete.
  argocd_platform_appproject = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata   = { name = "platform", namespace = "argocd" }
    spec = {
      description = "Platform infrastructure applications"
      sourceRepos = ["*"]
      destinations = [
        { namespace = "*", server = "https://kubernetes.default.svc" }
      ]
      clusterResourceWhitelist   = [{ group = "*", kind = "*" }]
      namespaceResourceWhitelist = [{ group = "*", kind = "*" }]
    }
  }

  argocd_root_application = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata   = { name = "root", namespace = "argocd" }
    spec = {
      project = "platform"
      source = {
        path           = "applications"
        repoURL        = var.gitops_repo_url
        targetRevision = "HEAD"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
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
  }

  argocd_manifests = [
    { name = "ns-argocd", contents = yamlencode(local.argocd_namespace) },
    { name = "argocd", contents = data.helm_template.argocd.manifest },
    { name = "argocd-age-keys-secret", contents = yamlencode(local.argocd_age_keys_secret) },
    { name = "argocd-repo-server-patch", contents = yamlencode(local.argocd_repo_server_patch) },
    { name = "argocd-httproute", contents = yamlencode(local.argocd_httproute) },
    { name = "argocd-platform-appproject", contents = yamlencode(local.argocd_platform_appproject) },
    { name = "argocd-root-application", contents = yamlencode(local.argocd_root_application) },
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

  set {
    name  = "configs.cm.url"
    value = "https://argocd.${var.domain}"
  }
}
