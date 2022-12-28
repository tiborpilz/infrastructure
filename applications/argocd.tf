resource "keycloak_openid_client" "argocd" {
  realm_id              = keycloak_realm.default.id
  client_id             = "argocd"
  name                  = "ArgoCD"
  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true
  valid_redirect_uris = [
    "https://argocd.${var.domain}/*"
  ]
}

resource "keycloak_generic_protocol_mapper" "argo_groups" {
  realm_id     = keycloak_realm.default.id
  client_id    = keycloak_openid_client.argocd.id
  name         = "groups"
  protocol     = "openid-connect"
  protocol_mapper = "oidc-usermodel-client-role-mapper"
  config = {
    "access.token.claim" = "true"
    "claim.name" = "groups"
    "full.path" = "true"
    "id.token.claim" = "true"
    "multivalued" = "true"
    "userinfo.token.claim" = "true"
    "usermodel.clientRoleMapping.clientId" = "argocd"
    "usermodel.clientRoleMapping.rolePrefix" = "argo:"
  }
}

resource "keycloak_openid_client_scope" "groups" {
  realm_id = keycloak_realm.default.id
  name     = "groups"
  description = "When requested, this scope will add the groups claim to the token"
  include_in_token_scope = true
}

resource "keycloak_openid_client_default_scopes" "argo_default_scopes" {
  realm_id  = keycloak_realm.default.id
  client_id = keycloak_openid_client.argocd.id

  default_scopes = [
    "profile",
    "email",
    "openid",
    keycloak_openid_client_scope.groups.name,
  ]
}

data "template_file" "argocd_values" {
  template = file("${path.module}/templates/argocd_values.tpl")
  vars = {
    domain = var.domain
    issuer_url = "https://auth.${var.domain}/auth/realms/default"
    client_id = keycloak_openid_client.argocd.client_id
    client_secret = keycloak_openid_client.argocd.client_secret
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.16.10"
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 600

  set {
    name  = "createCRD"
    value = false
  }

  set {
    name = "helm.versions"
    value = "v3"
  }

  values = [data.template_file.argocd_values.rendered]
}
