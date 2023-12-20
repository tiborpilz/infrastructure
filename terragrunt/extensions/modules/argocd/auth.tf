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
