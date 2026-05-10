provider "authentik" {
  url   = var.authentik_url
  token = var.authentik_token
  # Skip TLS verify is NOT enabled — the Gateway's wildcard cert from
  # cert-manager is real Let's Encrypt cert.
}
