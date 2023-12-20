terraform {
  required_providers {
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "4.1.0"
    }
    gitlab = {
      source = "gitlabhq/gitlab"
      version = "16.6.0"
    }
    kustomization = {
      source  = "kbst/kustomization"
      version = "0.9.5"
    }
  }
}

variable "argocd_version" {
  description = "The argocd (helm chart) version to use"
}

variable "keycloak_realm" {
  description = "The Keycloak realm id to use"
}

variable "domain" {
  description = "The domain to use"
}

variable "gitlab_infrastructure_project_id" {
  description = "The id of the infrastructure project in gitlab"
}

data "gitlab_project" "infrastructure" {
  id = var.gitlab_infrastructure_project_id
}

resource "gitlab_project_access_token" "infrastructure_argocd" {
  project = data.gitlab_project.infrastructure.id
  name = "argocd"
  scopes = ["read_repository"]
  expires_at = "2024-12-01"
}

data "kustomization_overlay" "argocd_repo_creds" {
  namespace = "argocd"
  common_labels = {
    "argocd.argoproj.io/secret-type": "repository"
  }

  secret_generator {
    name = "${lower(data.gitlab_project.infrastructure.name)}-repo-creds"
    namespace = helm_release.argocd.namespace
    behavior = "create"
    literals = [
      "type=git",
      "project=default",
      "url=${data.gitlab_project.infrastructure.http_url_to_repo}",
      "username=${data.gitlab_project.infrastructure.name}",
      "password=${gitlab_project_access_token.infrastructure_argocd.token}",
    ]
  }
}

resource "kustomization_resource" "argocd_repo_cred_p0" {
  for_each = data.kustomization_overlay.argocd_repo_creds.ids_prio[0]
  manifest = data.kustomization_overlay.argocd_repo_creds.manifests[each.value]
}

resource "kustomization_resource" "argocd_repo_cred_p1" {
  for_each = data.kustomization_overlay.argocd_repo_creds.ids_prio[1]
  manifest = data.kustomization_overlay.argocd_repo_creds.manifests[each.value]
  depends_on = [kustomization_resource.argocd_repo_cred_p0]
}

resource "kustomization_resource" "argocd_repo_cred_p2" {
  for_each = data.kustomization_overlay.argocd_repo_creds.ids_prio[2]
  manifest = data.kustomization_overlay.argocd_repo_creds.manifests[each.value]
  depends_on = [kustomization_resource.argocd_repo_cred_p1]
}

resource "kubernetes_manifest" "app_of_apps" {
  manifest = {
    "apiVersion" = "argoproj.io/v1alpha1"
    "kind"       = "Application"
    "metadata" = {
      "name" = "argocd-apps"
      "namespace" = "argocd"
    }
    "spec" = {
      "project" = "default"
      "source" = {
        "repoURL" = data.gitlab_project.infrastructure.http_url_to_repo
        "targetRevision" = "HEAD"
        "path" = "applications"
        "directory" = {
          "recurse" = false
        }
      }
      "destination" = {
        "namespace" = "default"
        "server" = "https://kubernetes.default.svc"
      }
    }
  }
}

data "template_file" "argocd_values" {
  template = file("${path.module}/templates/argocd_values.tpl")
  vars = {
    domain        = var.domain
    issuer_url    = "https://keycloak.${var.domain}/realms/default"
    client_id     = keycloak_openid_client.argocd.client_id
    client_secret = keycloak_openid_client.argocd.client_secret
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 600

  set {
    name  = "createCRD"
    value = true
  }

  set {
    name  = "helm.versions"
    value = "v3"
  }

  values = [data.template_file.argocd_values.rendered]
}

# resource "kubernetes_manifest" "argocd_app_of_apps" {
#   depends_on = [
#     helm_release.argocd,
#   ]
#   manifest = {
#     "apiVersion" = "argoproj.io/v1alpha1"
#     "kind"       = "Application"
#     "metadata" = {
#       "name" = "argocd-apps"
#       "namespace" = "argocd"
#     }
#     "spec" = {
#       "project" = "default"
#       "source" = {
#         "repoURL" = "https://gitlab.com/tiborpilz/infrastructure" # TODO: parameterize
#         "targetRevision" = "main"
#         "path" = "applications"
#       }
#       "destination" = {
#         "namespace" = "argocd"
#         "server" = "https://kubernetes.default.svc"
#       }
#     }
#   }
# }
