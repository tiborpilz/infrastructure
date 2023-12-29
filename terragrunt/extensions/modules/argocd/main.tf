terraform {
  required_providers {
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "4.3.1"
    }
    gitlab = {
      source  = "gitlabhq/gitlab"
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

variable "kube_config_yaml" {
  description = "The kube config yaml to use"
}

data "gitlab_project" "infrastructure" {
  id = var.gitlab_infrastructure_project_id
}

resource "gitlab_project_access_token" "infrastructure_argocd" {
  project    = data.gitlab_project.infrastructure.id
  name       = "argocd"
  scopes     = ["read_repository"]
  expires_at = "2024-12-01"
}

data "template_file" "repo_creds" {
  template = file("${path.module}/templates/repo_creds.tpl.yaml")
  vars = {
    repo_url = data.gitlab_project.infrastructure.http_url_to_repo
    username = data.gitlab_project.infrastructure.name
    password = gitlab_project_access_token.infrastructure_argocd.token
  }
}

data "template_file" "argocd_apps" {
  template = file("${path.module}/templates/argocd_apps.tpl.yaml")
  vars = {
    repo_url = data.gitlab_project.infrastructure.http_url_to_repo
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

resource "local_file" "manifests" {
  content = join("\n---\n", [
    data.template_file.repo_creds.rendered,
    data.template_file.argocd_apps.rendered,
  ])
  filename = "${path.module}/out/manifests.yaml"
}

resource "local_file" "kube_config" {
  content  = var.kube_config_yaml
  filename = "${path.module}/out/kube_config.yaml"
}

resource "null_resource" "apply_manifests" {
  depends_on = [helm_release.argocd]
  triggers = {
    manifests   = local_file.manifests.content
    kube_config = local_file.kube_config.content
  }
  provisioner "local-exec" {
    command = "kubectl --kubeconfig ${path.module}/out/kube_config.yaml  apply -f ${path.module}/out/manifests.yaml"
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
