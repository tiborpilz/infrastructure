# authentik ships these flows out of the box; we reuse them rather than
# defining custom ones. Slugs are stable across authentik versions.
data "authentik_flow" "default_authorization" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default_authentication" {
  slug = "default-authentication-flow"
}

data "authentik_flow" "default_invalidation" {
  slug = "default-provider-invalidation-flow"
}

# authentik provisions a self-signed cert on first boot and uses it as the
# default OIDC signing key. We reference it by name so token signing works
# without us managing a separate key.
data "authentik_certificate_key_pair" "default" {
  name = "authentik Self-signed Certificate"
}

# Default property mappings authentik creates on install. These tell
# authentik which user attributes to include in the OIDC userinfo response.
# Argo CD's `requestedScopes: [openid, profile, email, groups]` matches
# what these mappings emit.
data "authentik_property_mapping_provider_scope" "openid" {
  name = "authentik default OAuth Mapping: OpenID 'openid'"
}

data "authentik_property_mapping_provider_scope" "profile" {
  name = "authentik default OAuth Mapping: OpenID 'profile'"
}

data "authentik_property_mapping_provider_scope" "email" {
  name = "authentik default OAuth Mapping: OpenID 'email'"
}

# Groups scope. authentik doesn't ship a default 'groups' scope mapping
# under a stable name in 2026.x, so we define our own. Surfaces the user's
# authentik group memberships as a `groups` claim in the id_token; Argo CD's
# RBAC reads `groups` and matches against `policy.csv` (e.g.
# `g, platform-admins, role:admin`).
resource "authentik_property_mapping_provider_scope" "groups" {
  name       = "argocd-groups"
  scope_name = "groups"
  expression = "return {\"groups\": [group.name for group in user.ak_groups.all()]}"
}

resource "authentik_provider_oauth2" "argocd" {
  name          = "argocd"
  client_id     = var.argocd_oidc_client_id
  client_secret = var.argocd_oidc_client_secret

  authorization_flow = data.authentik_flow.default_authorization.id
  authentication_flow = data.authentik_flow.default_authentication.id
  invalidation_flow   = data.authentik_flow.default_invalidation.id

  signing_key = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = var.argocd_oidc_redirect_uri
    },
  ]

  property_mappings = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.profile.id,
    data.authentik_property_mapping_provider_scope.email.id,
    authentik_property_mapping_provider_scope.groups.id,
  ]

  # Stable subject across renames. `hashed_user_id` is the authentik default.
  sub_mode = "hashed_user_id"
}

resource "authentik_application" "argocd" {
  name              = "Argo CD"
  slug              = "argocd"
  protocol_provider = authentik_provider_oauth2.argocd.id
  meta_launch_url   = var.argocd_url
}
