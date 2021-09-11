variable "cluster_connection" {
  type = map(any)
  default = {}
}
variable domain {
  type = string
  default = ""
}

terraform {
  backend "local" {}
}

provider "kubernetes" {
  experiments {
    manifest_resource = true
  }

  host     = var.cluster_connection.api_server_url
  username = var.cluster_connection.kube_admin_user

  client_certificate     = var.cluster_connection.client_cert
  client_key             = var.cluster_connection.client_key
  cluster_ca_certificate = var.cluster_connection.ca_crt
}

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
