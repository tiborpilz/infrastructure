# Infrastructure

A self-contained, re-brandable platform: Talos Kubernetes on Hetzner Cloud
(plus optional Proxmox workers), provisioned with Terragrunt/OpenTofu and
delivered by an ArgoCD app-of-apps.

Everything a small org needs runs inside it, exposed as
`<service>.<domain>` behind one Cilium Gateway with a wildcard certificate
and single sign-on via Authentik:

| Service | What |
|---|---|
| Forgejo | git hosting |
| Woodpecker | CI (Kubernetes backend, wired to Forgejo) |
| Harbor | container registry |
| Authentik | identity provider / SSO (declarative blueprints) |
| ArgoCD | GitOps delivery |
| Headlamp, Hubble | cluster + network UIs (behind oauth2-proxy) |
| Longhorn, Rook/Ceph | storage |
| CNPG | PostgreSQL operator (per-service databases) |
| PDS, tangled | AT Protocol services |

## This instance

The identity of *this* instance (domain, repo URL, ACME email, cluster name)
lives in [`config/platform.yaml`](config/platform.yaml) — Terraform reads it
directly and the application layer is kept in sync by
[`scripts/rebrand`](scripts/rebrand).

**Adopting this repo for your own org:** see
[docs/rebranding.md](docs/rebranding.md) — fork, edit one config file, run
two scripts, `terragrunt apply`. Design rationale in
[docs/adr/0001](docs/adr/0001-instance-identity-model.md), secrets handling
in [docs/secrets.md](docs/secrets.md).

## Layout

```
config/               instance identity (single source of truth)
scripts/              rebrand, init-keys
terragrunt/           cluster provisioning: Hetzner/Proxmox → Talos →
                      bootstrap (Cilium, cert-manager, external-dns, Gateway,
                      ArgoCD + root Application)
applications/         ArgoCD app-of-apps, one directory per service
docs/                 ADRs, adoption + secrets guides
```

## Operating

```sh
devenv shell                      # terragrunt, tofu, talosctl, kubectl, sops, …
cd terragrunt/cluster && terragrunt apply
```

The bootstrap applies the ArgoCD root Application itself; after a successful
apply the cluster converges on whatever the default branch of this repo says.
A rendered copy of all bootstrap manifests is written to
`.kube/<cluster>-bootstrap-manifests.yaml` for inspection. Note that Talos
re-applies changed inline manifests but never deletes removed ones.

Secrets are sops/age-encrypted in place (`*.enc.yaml`, skeletons in
`*.enc.yaml.example`) — see [docs/secrets.md](docs/secrets.md).

## State encryption

State and plan files are encrypted client-side (`terragrunt/root.hcl`). The
passphrase comes from `state_passphrase` in `terragrunt/secrets.enc.yaml` or
`TF_STATE_PASSPHRASE`. To migrate existing unencrypted state: apply once per
unit, then set `state_encryption_migration = false`. Losing the passphrase
means losing the state.
