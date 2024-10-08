resource "keycloak_openid_client" "oauth2_proxy" {
  realm_id    = keycloak_realm.default.id
  client_id   = "oauth2-proxy"
  name        = "oauth2-proxy"
  description = "oauth2-proxy"
  root_url    = "https://oauth.${var.domain}"
  admin_url   = "https://oauth.${var.domain}"
  valid_redirect_uris = [
    "https://oauth.${var.domain}/*",
  ]
  web_origins                  = ["*"]
  access_type                  = "CONFIDENTIAL"
  standard_flow_enabled        = true
  implicit_flow_enabled        = false
  direct_access_grants_enabled = true
  service_accounts_enabled     = true
  # authorization_services_enabled = true
}

resource "keycloak_openid_group_membership_protocol_mapper" "group_membership_mapper" {
  realm_id            = keycloak_realm.default.id
  client_id           = keycloak_openid_client.oauth2_proxy.id
  name                = "groups"
  claim_name          = "groups"
  full_path           = "true"
  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
}

data "template_file" "oauth2_proxy_values" {
  template = file("${path.module}/templates/oauth2_proxy_values.tpl")
  vars = {
    domain        = var.domain
    issuer_url    = "https://keycloak.${var.domain}/realms/default"
    client_id     = keycloak_openid_client.oauth2_proxy.client_id
    client_secret = keycloak_openid_client.oauth2_proxy.client_secret
    cookie_secret = "HbRkRZf7fXtGML6iAEYOuCS7busPZCFt"
  }
}

resource "helm_release" "oauth2_proxy" {
  name             = "oauth2-proxy"
  repository       = "https://oauth2-proxy.github.io/manifests"
  chart            = "oauth2-proxy"
  version          = "7.7.24"
  namespace        = "oauth2-proxy"
  create_namespace = true
  values           = [data.template_file.oauth2_proxy_values.rendered]
}
