# Adopting this platform (rebranding)

This repository is a template for a self-contained platform: Talos
Kubernetes on Hetzner Cloud (plus optional Proxmox workers), bootstrapped by
Terragrunt/OpenTofu, with ArgoCD delivering everything under `applications/`
— git hosting (Forgejo), CI (Woodpecker), a registry (Harbor), SSO
(Authentik), storage (Longhorn/Rook), and more, all exposed as
`<service>.<your-domain>` behind one wildcard gateway.

Instance identity lives in `config/platform.yaml`; the design is documented
in [ADR 0001](adr/0001-instance-identity-model.md).

## Prerequisites

- a **domain** whose DNS zone is hosted on **Cloudflare** (cert-manager
  DNS-01 + external-dns are Cloudflare-only today)
- a **Hetzner Cloud** project + API token
- a GitHub (or any https-reachable) git host for your fork — ArgoCD pulls
  the default branch of `repo_url` unauthenticated, so the repo must be
  public or you add repo credentials to ArgoCD yourself
- locally: nix + [devenv](https://devenv.sh) (brings terragrunt, opentofu,
  talosctl, kubectl, sops, age, …) — or install those tools yourself
- optional: a Proxmox host if you want the hybrid worker setup (otherwise
  set `proxmox_workers = {}` in `terragrunt/cluster/terragrunt.hcl`)

## Walkthrough

```sh
# 1. fork / "Use this template", then clone your copy
git clone https://github.com/<you>/<your-infra>.git && cd <your-infra>

# 2. describe your identity
cp config/platform.example.yaml my.yaml && $EDITOR my.yaml

# 3. rewrite the tree (idempotent; --dry-run to preview)
scripts/rebrand my.yaml

# 4. new encryption keys + fresh secret files
age-keygen -o my.agekey        # your personal key — keep it out of the repo
scripts/init-keys --recipient "$(age-keygen -y my.agekey)" --force

# 5. fill in secrets (each *.enc.yaml.example documents its keys)
export SOPS_AGE_KEY_FILE=$PWD/my.agekey
sops edit terragrunt/secrets.enc.yaml    # tokens, state passphrase, …
# ... then the applications/**/secrets.enc.yaml you care about

# 6. review the manual checklist printed by scripts/rebrand (see below)

# 7. commit + push — ArgoCD will sync from this repo once bootstrapped
git add -A && git commit -m "rebrand to <you>" && git push

# 8. provision
devenv shell
cd terragrunt/cluster && terragrunt apply
```

The bootstrap installs Cilium, cert-manager (wildcard cert for
`*.<domain>`), external-dns, the shared Gateway, ArgoCD, **and the root
Application + AppProject** — after `terragrunt apply` succeeds, ArgoCD
syncs `applications/` on its own; there is no manual `kubectl apply` step.

## What `scripts/rebrand` does and does not do

It rewrites every literal occurrence of `domain`, `repo_url`, `acme_email`
and `cluster_name`, fails if any old value survives outside a small
allowlist, and updates `config/platform.yaml`. It deliberately leaves:

1. **Admin users** — `applications/identity/authentik/blueprints/users.yaml`
   defines the humans (usernames, emails, groups). Rename the entries, keep
   the group memberships, and align the password secret names in
   `applications/identity/authentik/users.enc.yaml` and the volume mounts in
   `applications/identity/authentik/argo-app.yaml`. Also update
   `WOODPECKER_ADMIN` in `applications/services/woodpecker/argo-app.yaml`.
2. **AT Protocol identity** — the PDS
   (`applications/services/pds/`) and tangled knot
   (`applications/services/tangled/`) derive handles and a `did:web` from the
   domain. These are *identities*, not hostnames: on a new domain you are
   creating new ones (regenerate `did.json` keys, pick your handle in
   `httproute-handles.yaml`/`dnsendpoint.yaml`). If you don't want atproto
   services at all, remove both entries from
   `applications/services/kustomization.yaml` and delete the directories.
3. **Site facts** — `terragrunt/env.hcl`: Hetzner location, network CIDRs,
   Talos version, Proxmox endpoint/node/datastores; node sizing lives in
   `terragrunt/cluster/terragrunt.hcl`. The cluster-autoscaler node pools
   (`applications/operators/cluster-autoscaler/argo-app.yaml`) hardcode the
   Hetzner location (`fsn1`) — change it if you picked another region.
4. **Encryption** — handled separately by `scripts/init-keys` (fresh
   instance) or `sops updatekeys` (existing instance); see
   [secrets.md](secrets.md).

## Known gaps / open TODOs

- `applications/argocd/` (ArgoCD self-management Application, chart 8.x) is
  **not** referenced by the app-of-apps; the bootstrap installs chart 7.x.
  Wiring it in hands ArgoCD upgrades to GitOps but changes cluster behavior,
  so it was left out of the rebranding work — decide deliberately.
- `ARGOCD_OIDC_CLIENT_SECRET` is Terraform-owned while a same-named GitOps
  SopsSecret carries the Harbor client secret (see
  [secrets.md](secrets.md#cross-file-invariants-keep-in-sync-by-hand)).
- OpenTofu state is local (client-side encrypted, `.terragrunt-state/`);
  fine for one operator, wrong for a team — a remote backend is future work.
- Single environment; there is no staging/prod split yet.
- The Cloudflare and Hetzner dependencies are hard requirements for now.
