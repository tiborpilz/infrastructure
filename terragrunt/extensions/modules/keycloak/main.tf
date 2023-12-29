terraform {
  required_providers {
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "4.3.1"
    }
  }
}

variable "admin_password" {
  type        = string
  description = "The admin password to use for keycloak"
}

variable "domain" {
  type        = string
  description = "The domain to use"
}

variable "users" {
  type = map(object({
    username   = string
    password   = string
    email      = string
    is_admin   = bool
    first_name = string
    last_name  = string
  }))
}

resource "keycloak_realm" "default" {
  realm   = "default"
  display_name = "${var.domain} - Auth"
  enabled = true
}


# TODO: Move user creation to module
resource "keycloak_user" "users" {
  for_each = var.users
  realm_id = keycloak_realm.default.id
  username = each.value.username
  enabled  = true

  email          = each.value.email
  email_verified = true

  first_name = each.value.first_name
  last_name  = each.value.last_name

  initial_password {
    value = each.value.password
  }

  attributes = {
    "is_admin" = each.value.is_admin
  }
}

data "keycloak_realm" "master" {
  realm = "master"
}

data "keycloak_role" "admin" {
  realm_id = data.keycloak_realm.master.id
  name     = "admin"
}

resource "keycloak_openid_client_scope" "groups" {
  realm_id               = keycloak_realm.default.id
  name                   = "groups"
  description            = "When requested, this scope will add the groups claim to the token"
  include_in_token_scope = true
}

# resource "keycloak_user_roles" "roles" {
#   for_each = keycloak_user.users

#   realm_id = keycloak_realm.default.id
#   user_id  = each.value.id

#   role_ids = each.value.attributes.is_admin ? [
#     data.keycloak_role.admin.id,
#   ] : []
#   exhaustive = false
# }


# TODO: also move group creation to module
resource "keycloak_group" "admin" {
  realm_id = keycloak_realm.default.id
  name     = "admin"
}

locals {
  # admin_users = [ for user in keycloak_user.users : user if user.attributes.is_admin ]
  admin_users = { for user in keycloak_user.users : user.username => user if user.attributes.is_admin }
}

resource "keycloak_group_memberships" "admin_membership" {
  realm_id = keycloak_realm.default.id
  group_id = keycloak_group.admin.id
  members = [
    for user in local.admin_users : user.username
  ]
}

# TODO: Move k8s stuff to module
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
  depends_on = [
    keycloak_openid_client.kubernetes,
    keycloak_realm.default,
  ]

  realm_id  = keycloak_realm.default.id
  client_id = keycloak_openid_client.kubernetes.id

  default_scopes = [
    "roles",
    "groups",
  ]
}

resource "keycloak_generic_protocol_mapper" "k8s_groups" {
  realm_id        = keycloak_realm.default.id
  client_scope_id = keycloak_openid_client_scope.groups.id
  name            = "k8s-groups"
  protocol        = "openid-connect"
  protocol_mapper = "oidc-usermodel-client-role-mapper"
  config = {
    "access.token.claim"                     = "true"
    "claim.name"                             = "groups"
    "full.path"                              = "true"
    "id.token.claim"                         = "true"
    "multivalued"                            = "true"
    "userinfo.token.claim"                   = "true"
    "usermodel.clientRoleMapping.clientId"   = "kubernetes"
    "usermodel.clientRoleMapping.rolePrefix" = "kubernetes:"
    "introspection.token.claim"            = "true"
  }
}


resource "kubernetes_cluster_role_binding" "oidc-cluster-admin" {
  for_each = local.admin_users
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
    name      = "https://keycloak.${var.domain}/realms/default#${each.value.username}"
    api_group = "rbac.authorization.k8s.io"
  }
}

output "realm" {
  value = keycloak_realm.default
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
