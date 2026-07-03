# Secrets

Everything secret in this repository is committed encrypted with
[sops](https://github.com/getsops/sops) and age. There is no unencrypted
secret material in git; the working set is `*.enc.yaml` files whose plaintext
skeletons live next to them as `*.enc.yaml.example`.

## Key model

| Key | Where the private part lives | Used by |
|---|---|---|
| in-cluster key (`argocd_age_key`) | `terragrunt/secrets.enc.yaml`, seeded from `.keys/platform.agekey` (gitignored) | ArgoCD repo-server (ksops render-time decryption) and sops-secrets-operator (in-cluster decryption) — both mounted by the Terraform bootstrap (`terragrunt/cluster/talos/bootstrap/{argocd,sops}.tf`) |
| personal key(s) | with each operator (e.g. a keychain or YubiKey) | humans running `sops edit`, terragrunt (which decrypts `terragrunt/secrets.enc.yaml` on every run) |

`.sops.yaml` has two rules:

1. `terragrunt/secrets.enc.yaml` — a flat key/value file; **every** value is
   encrypted.
2. all other `*.enc.yaml` — Kubernetes manifests; only `data`/`stringData`
   values are encrypted so the scaffolding stays parseable by kubectl and the
   SopsSecret operator.

Note: sops records the encryption settings per file, so files created before
a rule change keep their old shape until re-created. Two committed files
predate rule 2 and are encrypted wholesale
(`applications/services/hubble/secrets.enc.yaml` — see its `.example`).

## Two delivery mechanisms

- **`kind: SopsSecret`** (isindir sops-secrets-operator): the encrypted CR is
  applied to the cluster as-is; the operator decrypts in-cluster and manages
  the child Secrets. Used by forgejo, harbor, woodpecker, and the central
  authentik secrets.
- **ksops** (kustomize exec plugin): a raw `kind: Secret` is decrypted at
  render time inside the ArgoCD repo-server. Used by headlamp, hubble, pds,
  and tangled/knot (each app dir carries a `kustomization-ksops-generator.yaml`).

## Setting up a fresh instance

After `scripts/rebrand` (see docs/rebranding.md):

```sh
age-keygen -o my.agekey                       # your personal key; keep it safe
scripts/init-keys --recipient "$(age-keygen -y my.agekey)" --force
# --force replaces the *.enc.yaml inherited from the upstream instance,
# which your keys cannot decrypt anyway
sops edit terragrunt/secrets.enc.yaml         # fill in the CHANGEME values
```

then work through the remaining `*.enc.yaml` (the `.example` next to each
file documents every key and how to generate its value). Back up
`.keys/platform.agekey` — it is gitignored on purpose and the cluster cannot
decrypt anything without it.

## Day-2 operations

- edit a secret: `SOPS_AGE_KEY_FILE=my.agekey sops edit <file>`
- add a recipient: add the public key to `.sops.yaml`, then
  `sops updatekeys <file>` for every `*.enc.yaml`
- rotate the in-cluster key: generate a new keypair, swap it in
  `.sops.yaml` + `terragrunt/secrets.enc.yaml`, run `sops updatekeys` on all
  files, and re-apply the cluster bootstrap so the new private key reaches
  the repo-server and operator
- verify nothing is committed in plaintext: every `*.enc.yaml` value should
  read `ENC[AES256_GCM,...]`

## Cross-file invariants (keep in sync by hand)

These pairs hold the same value in two places; changing one without the
other breaks login for that service:

- Harbor OIDC client secret:
  `applications/identity/authentik/oidc-clients.enc.yaml`
  (`HARBOR_OIDC_CLIENT_SECRET`) ==
  `applications/services/harbor/secrets.enc.yaml` (`harbor-oidc.secret`)
- Forgejo OIDC client secret:
  `applications/identity/authentik/secrets.enc.yaml` (`forgejo-oidc.secret`)
  == `applications/services/forgejo/secrets.enc.yaml` (`forgejo-oidc.secret`)
  — the authentik-owned copy is reflected into the forgejo namespace, so
  these two secrets *also* collide by name there; consolidating to one owner
  is an open TODO.
- Authentik user password secret names (`<user>-password` in
  `users.enc.yaml`) must match the worker volume mounts in
  `applications/identity/authentik/argo-app.yaml` and the `!File` references
  in `blueprints/users.yaml`.

Known split ownership: `ARGOCD_OIDC_CLIENT_SECRET` is generated and applied
by Terraform (`terragrunt/cluster/talos/main.tf`, secret
`authentik-oidc-clients` in the authentik namespace), while a GitOps
SopsSecret of the **same name** carries `HARBOR_OIDC_CLIENT_SECRET`. Moving
the ArgoCD client secret fully into GitOps is an open TODO — until then,
be aware the two writers fight over that Secret's contents.

## Legacy keys

`terragrunt/secrets.enc.yaml` (the live one) still contains keys nothing
consumes anymore: `cloudflare_r2_*`, `hcloud_velero_*`, `omni_etcd_gpg_key`,
`fastmail_smtp_password`, `authentik_tibor_password`. They are omitted from
the `.example` and can be deleted on the next edit.
