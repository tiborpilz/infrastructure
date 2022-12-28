provider "keycloak" {
  client_id = "admin-cli"
  username  = "terraform"
  password  = "testpw12345"
  url       = "https://auth.${var.domain}/auth"
}

resource "keycloak_realm" "default" {
  realm   = "default"
  enabled = true
}

resource "keycloak_user" "tibor" {
  realm_id = keycloak_realm.default.id
  username = "tibor"
  enabled  = true

  email          = "tibor@pilz.berlin"
  email_verified = true

  first_name = "Tibor"
  last_name  = "Pilz"

  initial_password {
    value = "testpw12345"
  }
}

data "keycloak_realm" "master" {
  realm = "master"
}

data "keycloak_role" "admin" {
  realm_id = data.keycloak_realm.master.id
  name     = "admin"
}

resource "keycloak_user_roles" "tibor_roles" {
  realm_id = keycloak_realm.default.id
  user_id  = keycloak_user.tibor.id

  role_ids = [
    data.keycloak_role.admin.id,
  ]
  exhaustive = false
}

resource "keycloak_openid_client" "kubernetes" {
  realm_id              = keycloak_realm.default.id
  client_id             = "kubernetes"
  name                  = "Kubernetes"
  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true
  valid_redirect_uris = [
    "http://localhost:8000",
    "http://localhost:18000"
  ]
}

resource "keycloak_openid_client_default_scopes" "k8s_default_scopes" {
  realm_id  = keycloak_realm.default.id
  client_id = keycloak_openid_client.kubernetes.id

  default_scopes = [
    "roles",
    "openid",
    "groups",
  ]
}

resource "keycloak_generic_protocol_mapper" "k8s_groups" {
  realm_id         = keycloak_realm.default.id
  client_scope_id  = keycloak_openid_client_scope.groups.id
  name             = "k8s-groups"
  protocol         = "openid-connect"
  protocol_mapper  = "oidc-usermodel-client-role-mapper"
  config = {
    "access.token.claim"                     = "true"
    "claim.name"                             = "groups"
    "full.path"                              = "true"
    "id.token.claim"                         = "true"
    "multivalued"                            = "true"
    "userinfo.token.claim"                   = "true"
    "usermodel.clientRoleMapping.clientId"   = "kubernetes"
    "usermodel.clientRoleMapping.rolePrefix" = "kubernetes:"
  }
}

#       "client" = {
#         "clientId" = "kubernetes"
#         "protocol" = "openid-connect"
#         "protocolMappers" = [
#           {
#             "config" = {
#               "access.token.claim" = "true"
#               "claim.name" = "groups"
#               "full.path" = "true"
#               "id.token.claim" = "true"
#               "multivalued" = "true"
#               "userinfo.token.claim" = "true"
#               "usermodel.clientRoleMapping.clientId" = "kubernetes"
#               "usermodel.clientRoleMapping.rolePrefix" = "kubernetes:"
#             }
#             "consentRequired" = false
#             "name" = "groups"
#             "protocol" = "openid-connect"
#             "protocolMapper" = "oidc-usermodel-client-role-mapper"
#           },
#         ]


#         "redirectUris" = [
#           "http://localhost:8000",
#           "http://localhost:18000",
#         ]
#         "standardFlowEnabled" = true

resource "kubernetes_cluster_role_binding" "oidc-cluster-admin" {
    metadata {
        name = "oidc-cluster-admin"
    }

    role_ref {
        api_group = "rbac.authorization.k8s.io"
        kind      = "ClusterRole"
        name      = "cluster-admin"
    }

    subject {
        kind      = "User"
        name      = "https://auth.${var.domain}/auth/realms/default#${keycloak_user.tibor.id}"
        api_group = "rbac.authorization.k8s.io"
    }
}
