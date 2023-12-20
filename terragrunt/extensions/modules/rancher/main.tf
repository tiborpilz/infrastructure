terraform {
  required_providers {
    rancher2 = {
      source  = "rancher/rancher2"
      version = "3.0.0"
    }
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "4.1.0"
    }
  }
}

variable rancher_version {
  type        = string
  description = "The rancher (helm chart) version to use"
}

variable rancher_initial_password {
  type        = string
  description = "The initial password to use for rancher"
}

variable email {
  type        = string
  description = "The email address to use for the certificate"
}

variable domain {
  type        = string
  description = "The domain to use"
}

variable keycloak_realm {
  description = "The Keycloak realm to use"
}

resource "helm_release" "rancher" {
  name             = "rancher"
  repository       = "https://releases.rancher.com/server-charts/latest"
  chart            = "rancher"
  version          = var.rancher_version
  namespace        = "cattle-system"
  create_namespace = true
  values = [yamlencode({
    hostname = "rancher.${var.domain}"
    ingress = {
      tls = {
        source = "letsEncrypt"
      }
      extraAnnotations = {
        "kubernetes.io/ingress.class" = "nginx"
      }
    }
    letsEncrypt = {
      email = var.email
      ingress = {
        class = "nginx"
      }
    }
    bootstrapPassword = var.rancher_initial_password
  })]

  provisioner "local-exec" {
    command    = "while true; do curl -k 'https://rancher.${var.domain}' && break || sleep 3; done"
    on_failure = continue
  }
}

provider "rancher2" {
  alias     = "bootstrap"
  api_url   = "https://rancher.${var.domain}"
  bootstrap = true
}

resource "rancher2_bootstrap" "admin" {
  provider         = rancher2.bootstrap
  initial_password = var.rancher_initial_password
  password         = var.rancher_initial_password
  telemetry        = false
}

provider "rancher2" {
  alias     = "admin"
  api_url   = rancher2_bootstrap.admin.url
  token_key = rancher2_bootstrap.admin.token
  insecure  = true
}

# Keycloak stuff

# Create openssl key and certificate
resource "tls_private_key" "rancher" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "keycloak_openid_client" "rancher_oidc" {
  realm_id  = var.keycloak_realm.id
  client_id = "rancher"
  name      = "rancher"

  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true
  valid_redirect_uris   = ["https://rancher.${var.domain}/verify-auth"]
}

resource "keycloak_openid_client_scope" "rancher_oidc" {
  realm_id = var.keycloak_realm.id
  name     = "rancher"
}

resource "keycloak_openid_client_default_scopes" "client_default_scopes" {
  realm_id  = var.keycloak_realm.id
  client_id = keycloak_openid_client.rancher_oidc.id

  default_scopes = [
    "profile",
    "email",
    "roles",
    "web-origins",
    keycloak_openid_client_scope.rancher_oidc.name,
  ]
}

resource "keycloak_openid_group_membership_protocol_mapper" "rancher_group_mapper" {
  realm_id  = var.keycloak_realm.id
  client_id = keycloak_openid_client.rancher_oidc.id

  name       = "Groups Mapper"
  claim_name = "groups"

  add_to_id_token     = false
  add_to_access_token = false
  add_to_userinfo     = true
}

resource "keycloak_openid_audience_protocol_mapper" "rancher_audience_mapper" {
  realm_id  = var.keycloak_realm.id
  client_id = keycloak_openid_client.rancher_oidc.id
  name      = "Client Audience"

  included_client_audience = keycloak_openid_client.rancher_oidc.name
  add_to_access_token      = true
}

resource "keycloak_openid_group_membership_protocol_mapper" "rancher_group_path_mapper" {
  realm_id  = var.keycloak_realm.id
  client_id = keycloak_openid_client.rancher_oidc.id

  name       = "Group Path"
  claim_name = "full_group_path"

  full_path       = true
  add_to_userinfo = true
}

data "http" "keycloak_saml" {
  url = "https://keycloak.${var.domain}/realms/${var.keycloak_realm.realm}/protocol/saml/descriptor"
}

resource "rancher2_token" "auth" {
  provider = rancher2.admin
  ttl      = 1200
}

locals {
  rancher_configuration_data = {
    accessMode         = "unrestricted"
    authEndpoint       = "https://keycloak.${var.domain}/realms/${var.keycloak_realm.realm}/protocol/openid-connect/auth"
    clientId           = keycloak_openid_client.rancher_oidc.client_id
    clientSecret       = keycloak_openid_client.rancher_oidc.client_secret
    created            = timestamp()
    creatorId          = null
    enabled            = true
    groupSearchEnabled = null
    issuer             = "https://keycloak.${var.domain}/realms/${var.keycloak_realm.realm}"
    labels = {
      "cattle.io/creator" = "norman"
    }
    name            = "keycloakoidc"
    ownerReferences = []
    rancherUrl      = "https://rancher.${var.domain}/verify-auth"
    scope           = "openid profile email"
    type            = "keyCloakOIDCConfig"
    uuid            = "0d2a7261-4af8-5b53-5bcf-6a36cb094cd1"
  }
}

resource "null_resource" "configure_keycloak_oidcs" {
  triggers = {
    rancher_configuration_data = jsonencode(local.rancher_configuration_data)
  }
  provisioner "local-exec" {
    command = <<EOT
       curl -k --insecure -u '${rancher2_token.auth.access_key}:${rancher2_token.auth.secret_key}'  \
        -X PUT \
        -H 'Accept: application/json' \
        -H 'Content-Type: application/json' \
        -d '${jsonencode(local.rancher_configuration_data)}' \
        ${rancher2_bootstrap.admin.url}/v3/keyCloakOIDCConfigs/keycloakoidc?action=testAndApply
EOT
  }
}

resource "rancher2_global_role" "admin" {
  provider    = rancher2.admin
  name        = "admin"
  description = "Admin role"
  rules {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

# resource "rancher2_global_role_binding" "admin" {
#   name = "admin"
#   global_role_id = rancher2_global_role.admin.id
#   group_principal_id =
# }

# resource "rancher2_auth_config_keycloak" "keycloak" {
#   provider = "rancher2.admin"



# display_name_field   = "givenName"
# user_name_field      = "email"
# uid_field            = "email"
# groups_field         = "member"
# entity_id            = "https://rancher.${var.domain}/v1-saml/keycloak/saml/metadata"
# rancher_api_host     = rancher2_bootstrap.admin.url
# sp_cert              = tls_private_key.rancher.public_key_openssh
# sp_key               = tls_private_key.rancher.private_key_pem
# idp_metadata_content = data.http.keycloak_saml.response_body
# }

# output "private_key" {
#   value = tls_private_key.rancher.private_key_pem
# }

# resource "local_file" "public_key" {
#   content  = tls_private_key.rancher.public_key_openssh
#   filename = "rancher.key"
# }

# This should work, but is currently broken in newer versions: https://github.com/mrparkers/terraform-provider-keycloak/issues/820
#
# data "keycloak_saml_client_installation_provider" "rancher_saml_idp_descriptor" {
#   realm_id    = var.keycloak_realm.id
#   client_id   = keycloak_saml_client.rancher.id
#   provider_id = "saml-idp-descriptor"
# }

# A workaround, although an ugly one, is to use the http data resource and directly fetch the metadata from the keycloak server, as it's publicly available
# and not bound to the saml client.
# Terraform will, hoever, complain about the response type.
