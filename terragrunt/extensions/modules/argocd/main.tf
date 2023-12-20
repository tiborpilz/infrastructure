terraform {
  required_providers {
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "4.1.0"
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

resource "keycloak_openid_client" "argocd" {
  realm_id              = var.keycloak_realm.id
  client_id             = "argocd"
  name                  = "ArgoCD"
  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true
  valid_redirect_uris = [
    "https://argocd.${var.domain}/*"
  ]
}

resource "keycloak_generic_protocol_mapper" "argo_groups" {
  realm_id        = var.keycloak_realm.id
  client_id       = keycloak_openid_client.argocd.id
  name            = "groups"
  protocol        = "openid-connect"
  protocol_mapper = "oidc-usermodel-client-role-mapper"
  config = {
    "access.token.claim"                     = "true"
    "claim.name"                             = "groups"
    "full.path"                              = "true"
    "id.token.claim"                         = "true"
    "multivalued"                            = "true"
    "userinfo.token.claim"                   = "true"
    "usermodel.clientRoleMapping.clientId"   = "argocd"
    "usermodel.clientRoleMapping.rolePrefix" = ""
  }
}

resource "keycloak_openid_group_membership_protocol_mapper" "argo_group_membership" {
  realm_id        = var.keycloak_realm.id
  client_id       = keycloak_openid_client.argocd.id
  name            = "group-membership"
  claim_name      = "groups"
  full_path       = false
}

resource "keycloak_openid_client_default_scopes" "argo_default_scopes" {
  realm_id  = var.keycloak_realm.id
  client_id = keycloak_openid_client.argocd.id

  default_scopes = [
    "profile",
    "email",
    "openid",
    "groups",
  ]
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
