# `authentik-config` module — general-only authentik state

Configures authentik state that is **not** specific to any consuming app.

## What this layer does

- Creates platform-level groups: `platform-admins`, `kubernetes-admins`. These are placeholder groups that downstream RBAC bindings reference — e.g., the kube-apiserver OIDC config (`oidc-groups-prefix: oidc:`) maps an `oidc:kubernetes-admins` Group claim to a `ClusterRoleBinding` for `cluster-admin`.

## What this layer does NOT do

- **No per-app OIDC clients.** Each consumer module owns its own `authentik_provider_oauth2` + `authentik_application` + `random_password` for the OIDC client_secret. See the root README's "Per-app identity convention" section.
- **No `akadmin` password pinning.** `40-authentik` already pins it via `AUTHENTIK_BOOTSTRAP_PASSWORD` (sourced from a `random_password` in TF state). authentik's bootstrap loop re-applies that password on every worker start.
- **No SMTP / branding / MFA enforcement.** Add when there's a concrete need.

## Inputs

- `authentik_url`, `authentik_token` — from `40-authentik`
- `authentik_ready` — sentinel from `40-authentik`, forces dependency
- `platform_groups` — list of group names to create. Default: `[platform-admins, kubernetes-admins]`

## Outputs

- `platform_groups` — names of created groups (echo of the input). Useful for downstream layers that bind RBAC.

## Notes

- **Provider authentication:** uses the bootstrap admin token. Because that token is `random_password`-generated and stable across re-applies, the provider keeps working without rotation. Rotate by tainting the `random_password.bootstrap_admin_token` resource in `40-authentik`.
- **Why so thin?** This layer is the home for general authentik state that doesn't belong with any specific app. The list will grow naturally — first SMTP config when the first email-sending feature is needed, branding when the user-visible UI gets touched, etc. Resist the urge to put per-app clients here.
