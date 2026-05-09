# `argocd-oidc` module — glue layer for Argo CD OIDC via authentik

Creates the authentik objects that match the OIDC client_secret baked into Argo CD's Helm values by `20-argocd`.

## Why this is its own layer

The per-app identity convention (root `README.md`) says each consumer module owns BOTH the deployment and the matching authentik client. That works for apps deployed AFTER authentik. Argo CD is special: it's deployed BEFORE authentik (because authentik runs AS an Argo CD Application), so `20-argocd` can't `dependency` on `40-authentik` without a cycle.

Resolution: split.

- `20-argocd` generates the OIDC client_secret as a `random_password` and bakes it into the Argo CD Helm chart values (`configs.cm.oidc.config` + `configs.secret.extra`). Doesn't talk to authentik.
- `50-argocd-oidc` (this module) is downstream of `40-authentik`. Reads `20-argocd`'s outputs (client_id, client_secret, redirect URI), creates the matching `authentik_provider_oauth2` + `authentik_application`.

Both sides converge on the same client_secret. Order of apply doesn't strictly matter for the secret to match (since both sides reference the same TF state value), but the OIDC handshake at user login time only succeeds once both apply.

## What this layer creates

- `authentik_provider_oauth2.argocd` — OAuth2/OIDC provider with the redirect URI whitelisted, signed with authentik's default self-signed cert, scopes `openid profile email groups`.
- `authentik_application.argocd` — application entry visible in authentik's user portal.

## Inputs

- `authentik_url`, `authentik_token`, `authentik_ready` — from `40-authentik`
- `argocd_url`, `argocd_oidc_client_id`, `argocd_oidc_client_secret`, `argocd_oidc_redirect_uri` — from `20-argocd`

## Outputs

- `argocd_application_slug` — the slug used in the OIDC issuer URL (`<authentik_url>/application/o/<slug>/`)
- `argocd_provider_id` — provider numeric ID, useful for any future `authentik_policy_binding`

## Notes

- **Default flows:** authentik ships `default-provider-authorization-implicit-consent`, `default-authentication-flow`, and `default-provider-invalidation-flow` on every install. Reusing them avoids managing custom flows for what is a vanilla OIDC client.
- **Signing key:** authentik provisions a self-signed `authentik Self-signed Certificate` on first boot. That's used as the OIDC signing key. For external trust (e.g. if Argo CD pinned the JWKS URI), this works because Argo CD fetches the JWKS via the discovery endpoint at login time.
- **Groups claim:** the `goauthentik default OAuth Mapping: OpenID 'groups'` scope mapping emits `groups` in the userinfo. Argo CD's `policy.csv` matches against this claim.
- **Rotating client_secret:** taint `random_password.argocd_oidc_client_secret` in `20-argocd`, apply both layers. Both sides converge on the new secret; existing user sessions are rejected on next refresh.
