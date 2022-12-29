# Add values file to repo
# Generate argo app from k8s
# Maybe add user federation

resource "kubernetes_manifest" "terrakube" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "terrakube"
      namespace = "argocd"
    }
    spec = {
      destination = {
        name      = "in-cluster"
        namespace = "terrakube"
        server    = ""
      }
      project = "default"
      source = {
        path           = "manifests/terrakube"
        repoURL        = "https://gitlab.com/bababourbaki/infrastructure"
        targetRevision = "apps"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
        ]
      }
    }
  }
  wait_for = {
    "status.health.status" = "Healthy"
  }
}
