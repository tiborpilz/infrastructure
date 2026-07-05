# Coder

[Coder](https://coder.com) self-hosted development-environment platform, served at
`https://coder.tibor.sh`.

## Layout

| File | Purpose |
| --- | --- |
| `argo-app.yaml` | ArgoCD `Application` deploying the Coder Helm chart (`https://helm.coder.com/v2`). Postgres via `CODER_PG_CONNECTION_URL`, OIDC via Authentik, `serviceAccount.enableDeployments` so the built-in Kubernetes provisioner can create workspace pods. |
| `database.yaml` | cnpg `Cluster` `coder-db` (secret `coder-db-app`, service `coder-db-rw`). |
| `httproute.yaml` | Gateway API route `coder.tibor.sh` → `coder` service. |
| `blueprints/oidc.yaml` | Authentik OAuth2 provider + application `coder`. Collected by `applications/_generators/blueprints-aggregator.sh`. |
| `secrets.enc.yaml` | sops-encrypted `SopsSecret` holding the shared OIDC `client-secret` (`coder-oidc`), annotated for reflection into the `authentik` namespace — same pattern as `forgejo/secrets.enc.yaml`. |
| `templates/nix-devbox/` | A Coder workspace template reproducing the neovim/zsh/tmux config from `github:tiborpilz/nixos`. See its README. |

## Auth flow

1. The `SopsSecret` in `secrets.enc.yaml` creates `coder-oidc` (a fixed `client-secret`) in
   the `coder` namespace, annotated for reflection into `authentik`. This is declarative and
   race-free — the secret exists before Coder's pod needs it (unlike a bootstrap Job that
   would sync in a separate ArgoCD Application).
2. Authentik exposes it as `CODER_OIDC_CLIENT_SECRET`
   (`applications/identity/authentik/argo-app.yaml`); `blueprints/oidc.yaml` sets the
   provider's `client_secret` from that env.
3. Coder reads the same secret and points `CODER_OIDC_ISSUER_URL` at
   `https://auth.tibor.sh/application/o/coder/`.

The first user to sign in via Authentik becomes the Coder owner. Authentik must roll once
after the `coder-oidc` secret first appears (ArgoCD self-heal handles this).

> The secret is encrypted to the three age recipients in `.sops.yaml` (the operator decrypts
> with the `argocd` age key). To also add the PGP recipient for parity with the other
> secrets, run `sops updatekeys applications/services/coder/secrets.enc.yaml`.

## Known limitations

- **Subdomain apps disabled.** The `*.tibor.sh` wildcard cert/DNS is single-label, so
  `*.coder.tibor.sh` app URLs are not covered. `CODER_WILDCARD_ACCESS_URL` is empty; Coder
  uses path-based app access. Add a `*.coder.tibor.sh` DNS record + cert to enable subdomain
  apps.
