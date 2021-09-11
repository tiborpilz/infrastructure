resource "kubernetes_manifest" "keycloak-application" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind = "Application"
    metadata = {
      finalizers = [
        "resources-finalizer.argocd.argoproj.io",
      ]
      name = "keycloak"
      namespace = "argocd"
    }
    spec = {
      destination = {
        name = "in-cluster"
        namespace = "keycloak"
        server = ""
      }
      project = "default"
      source = {
        path = "applications/manifests/keycloak"
        repoURL = "git@github.com:tiborpilz/infrastructure.git"
        targetRevision = "HEAD"
      }
      syncPolicy = {
        automated = {
          prune = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
        ]
      }
    }
  }
  wait_for = {
    fields = {
      "status.health.status" = "Healthy"
    }
  }
}

