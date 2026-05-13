# Infrastructure

Scaffoldable Kubernetes platform on Hetzner. See [`PLAN.md`](./PLAN.md) for the full design rationale, constraints, and milestone roadmap.

## Layers

The `terragrunt/` directory contains the staged Terragrunt stack. Each stage keeps its `terragrunt.hcl`, Terraform entrypoint, and owned component modules together. Apply order is enforced by `dependency` blocks; `terragrunt run --all apply` walks the graph correctly.

| Layer | Purpose |
| --- | --- |
| `cluster` | Hetzner network + VMs, Talos config/bootstrap. Outputs kubeconfig material and cloud IDs. |
| `platform` | Cluster-wide infra: Cilium (CNI + Gateway), Argo CD, networking (cert-manager, external-dns), hcloud-csi, CNPG operator, metrics-server, longhorn (opt-in storage), kube-prometheus-stack (observability), authentik. |
| `services` | Layer that talks to live application APIs: authentik users/groups + invitation flow, Argo CD OIDC, Forgejo, Woodpecker, Tekton (operator + dashboard via oauth2-proxy), Omni (gated on `omni_etcd_gpg_key` in SOPS), Hubble UI via oauth2-proxy. |
| `modules/` | Reusable cross-unit modules. Currently: `hcloud-nixos-server` — provisions a Hetzner VM + first-boot `nixos-anywhere` install. Used by future `vms/<workload>/` units for NixOS workloads adjacent to the cluster (Hydra, etc.). |

### Storage classes

- `hcloud-volumes` (default): Hetzner block storage, network-attached. For durable workloads where node death must not lose data (CNPG postgres, Forgejo, Omni etcd).
- `longhorn` (opt-in): replicated block storage on local disks. For workloads that can be rebuilt (Prometheus retention, Grafana dashboards, Tekton workspaces). Requires the `siderolabs/iscsi-tools` Talos extension.

### Identity model

- Per-app OIDC client lives with the app (convention in `services/<app>/`).
- Native OIDC when the app speaks it: Argo CD, Forgejo, Grafana, Omni.
- oauth2-proxy in front when the app doesn't: Hubble UI, Tekton Dashboard.
- Forgejo's local login form is disabled (`ENABLE_INTERNAL_SIGNIN: false`); break-glass via `kubectl exec` + `forgejo admin user`.
- Argo CD default RBAC is no-access; only `platform-admins` get any role at all.

### CI/CD

- Woodpecker: general-purpose CI (`npm`, web builds, etc.), in-cluster k8s runner.
- Tekton: Kubernetes-native pipelines, Triggers (webhook-driven), Chains (SLSA provenance). Dashboard at `tekton.<domain>` behind oauth2-proxy.
- NixOS / Hydra: runs on the homeserver, not in cluster. If a second Nix workload appears, use the `hcloud-nixos-server` module to provision an adjacent VM.

### Known scoping decisions

- Self-hosted Omni runs in the same cluster it would manage. Documented foot-gun: this cluster isn't recoverable from Omni. Omni is for spinning up *other* clusters; SideroLink reaches managed nodes via NodePort `30180/UDP` (Hetzner firewall has the rule).
- No KubeVirt. Considered and rejected: Hetzner CPX has no `/dev/kvm`, and CCX-with-nested-virt is ~€16/mo always-on. The adjacent-VM pattern (`hcloud-nixos-server`) covers the NixOS-shaped use case at €4-5/mo per workload.

If an environment has already been applied with the older `terragrunt/envs/hcloud-poc` per-component layer layout, migrate the local Terraform state before applying this layout. The backend path and module addresses changed: state now lives under `.terragrunt-state/<stage>/...`, and resources are nested under stage modules such as `module.hcloud`, `module.talos`, `module.argocd`, and `module.forgejo`. Applying without a state migration will look like a fresh install.

## Per-app identity convention

When a future module deploys a core app that consumes authentik OIDC, it owns BOTH the app's deployment and its authentik client config. Layout inside the module:

```hcl
# random_password lives in TF state; never in Git
resource "random_password" "oidc_client_secret" {
  length  = 48
  special = false
}

resource "authentik_provider_oauth2" "this" {
  name           = "<app>"
  client_id      = "<app>"
  client_secret  = random_password.oidc_client_secret.result
  redirect_uris  = [{ matching_mode = "strict", url = "https://<app>.<domain>/oauth/callback" }]
  authorization_flow = data.authentik_flow.default_authorization.id
  authentication_flow = data.authentik_flow.default_authentication.id
}

resource "authentik_application" "this" {
  name              = "<app>"
  slug              = "<app>"
  protocol_provider = authentik_provider_oauth2.this.id
}

# Consumed by the app's Helm chart via valuesObject or env
resource "kubernetes_secret" "<app>_oidc" {
  metadata {
    namespace = "<app>"
    name      = "<app>-oidc"
  }
  data = {
    client_id     = authentik_provider_oauth2.this.client_id
    client_secret = random_password.oidc_client_secret.result
    issuer_url    = "${var.authentik_url}/application/o/<app>/"
  }
}

resource "kubectl_manifest" "argo_app_<app>" {
  # Argo CD Application that references the secret above
  ...
}
```

Why a `services` layer? Some resources use live application APIs, not just Kubernetes: the authentik provider needs authentik to be reachable, and the Gitea provider needs Forgejo to be reachable. Those are real bootstrap boundaries. Inside that layer, per-app identity clients still live with their consumers rather than in one giant cross-app config module.

Argo CD is the exception. Argo CD is deployed before authentik, so the convention can't apply directly: `platform` can't depend on post-bootstrap identity config without a cycle. Instead, it generates the OIDC client_secret as a `random_password` and bakes it into the Helm values; `services` creates the matching authentik objects. Future apps deployed after authentik follow the documented convention as-is.

What lives in shared authentik config? Only state that isn't tied to a specific app: platform groups, declarative managed users, branding, SMTP, MFA policies, default flows. The `akadmin` password is already pinned upstream by `platform` (TF-generated `random_password` mounted as `AUTHENTIK_BOOTSTRAP_PASSWORD`). Managed user passwords can be supplied from SOPS later, or omitted so Terraform creates stable random passwords.

Forgejo follows the convention. The Forgejo module inside `services` owns the Forgejo Argo CD Application, matching authentik OAuth2 provider/Application, generated Kubernetes Secrets, Forgejo chart values, and the CNPG `Cluster` template. For this bootstrap slice, the Argo CD Application reads the upstream Forgejo chart directly and Terraform passes the rendered values/extra resources, so it does not depend on a platform repo commit being pushed first. SSH and Forgejo's package registry are intentionally deferred.

## Reaching the cluster

After `terragrunt run --all apply`:

```sh
export KUBECONFIG=.kube/hcloud-poc.kubeconfig
kubectl get nodes
```

authentik bootstrap admin password (first login):

```sh
terragrunt --working-dir terragrunt/platform output -raw bootstrap_admin_password
```

## Backups

`platform` runs Velero (Kopia file-system backup) and a Talos etcd snapshot CronJob, both targeting one Hetzner Object Storage bucket per env (`backups-<env_name>`). Layout: `velero/` for cluster + PV backups, `etcd/` for raw etcd snapshots.

**One-time prerequisite.** Hetzner Object Storage S3 access keys aren't yet creatable via the `hcloud` Terraform provider. Generate them once in the Hetzner Console (Project → Security → Object Storage) and export:

```sh
export HCLOUD_S3_ACCESS_KEY=...
export HCLOUD_S3_SECRET_KEY=...
```

The bucket itself is created by `platform` via the `aminueza/minio` Terraform provider pointed at Hetzner's S3 endpoint; no manual bucket setup needed. (Migrating these creds to SOPS is on the M2 list.)

**Defaults.**

- Velero: daily backup at 02:00 cluster time, 14-day retention, all namespaces.
- etcd snapshots: every 6 hours, 7-day retention.

**Restore drill** (run quarterly — untested backups are not backups):

```sh
# Create a throwaway namespace, back it up, delete, restore.
kubectl create ns smoke-restore
kubectl -n smoke-restore create deploy nginx --image=nginx
velero backup create smoke-$(date +%s) --include-namespaces smoke-restore --wait
kubectl delete ns smoke-restore
velero restore create --from-backup smoke-... --wait
kubectl -n smoke-restore get deploy nginx
```

`velero` is in the dev shell (`flake.nix`).

## Local development

`shell.nix` / `flake.nix` pin the toolchain. `nix develop` (or `direnv allow`) brings in `terragrunt`, `tofu`, `talosctl`, `kubectl`, `argocd`, `helm`, `velero`, etc.
