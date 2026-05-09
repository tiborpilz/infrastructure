# Infrastructure

Scaffoldable Kubernetes platform on Hetzner. See [`PLAN.md`](./PLAN.md) for the full design rationale, constraints, and milestone roadmap.

## Layers

The `terragrunt/envs/<env>/` directory contains the layered Terragrunt stacks. Apply order is enforced by `dependency` blocks; `terragrunt run --all apply` walks the graph correctly.

| Layer | Purpose |
| --- | --- |
| `00-machines` | Hetzner network + VMs. Outputs a generic node inventory. |
| `10-cluster` | Talos config + bootstrap. Outputs kubeconfig material. |
| `20-argocd` | Cilium (CNI + Gateway API), Hetzner CCM, Argo CD, AppProjects. |
| `30-networking` | cert-manager, external-dns, public Gateway. |
| `30-smoke-app` | Trivial nginx behind the Gateway. End-to-end TLS/DNS proof. |
| `35-platform-data` | hcloud-csi (`hcloud-volumes` StorageClass) + CloudNativePG operator. |
| `37-velero` | Velero (Kopia file-system backup) + Talos etcd snapshot CronJob → Hetzner Object Storage. |
| `40-authentik` | authentik (OIDC provider) + CNPG `Cluster` + inlined Valkey. |
| `45-authentik-config` | General authentik state — platform groups and declarative managed users. No per-app clients. |
| `50-argocd-oidc` | Glue layer: creates the authentik objects matching Argo CD's TF-baked OIDC client. See "Argo CD exception" below. |
| `55-forgejo` | Forgejo at `git.<domain>` + CNPG `Cluster` + app-owned authentik OIDC client/secrets. |

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

**Why not a central `40-post-config` layer?** PLAN.md flagged that as awkward. Colocating the identity client with the consumer means adding/removing an app is one module change, the dependency graph stays local, and there's no single layer that knows about every app. Multiple core apps may share one Terragrunt env layer (e.g. `50-core-apps`) — they don't each need a dedicated layer.

**Argo CD is the exception.** Argo CD is deployed before authentik (because authentik runs as an Argo CD Application), so the convention can't apply directly — `20-argocd` can't `dependency` on `40-authentik` without a cycle. Instead, `20-argocd` generates the OIDC client_secret as a `random_password` and bakes it into the Helm values; a downstream glue layer `50-argocd-oidc` creates the matching authentik objects. Future apps deployed AFTER authentik (Forgejo, Woodpecker, Grafana, ...) follow the documented convention as-is.

**What lives in `45-authentik-config`?** Only state that isn't tied to a specific app: platform groups, declarative managed users, branding, SMTP, MFA policies, default flows. The `akadmin` password is already pinned upstream by `40-authentik` (TF-generated `random_password` mounted as `AUTHENTIK_BOOTSTRAP_PASSWORD`). Managed user passwords can be supplied from SOPS later, or omitted so Terraform creates stable random passwords.

**Forgejo follows the convention.** `55-forgejo` owns the Forgejo Argo CD Application, matching authentik OAuth2 provider/Application, generated Kubernetes Secrets, Forgejo chart values, and the CNPG `Cluster` template. For this bootstrap slice, the Argo CD Application reads the upstream Forgejo chart directly and Terraform passes the rendered values/extra resources, so it does not depend on a platform repo commit being pushed first. SSH and Forgejo's package registry are intentionally deferred.

## Reaching the cluster

After `terragrunt run --all apply`:

```sh
export KUBECONFIG=.kube/hcloud-poc.kubeconfig
kubectl get nodes
```

authentik bootstrap admin password (first login):

```sh
terragrunt --working-dir terragrunt/envs/hcloud-poc/40-authentik output -raw bootstrap_admin_password
```

## Backups

`37-velero` runs Velero (Kopia file-system backup) and a Talos etcd snapshot CronJob, both targeting one Hetzner Object Storage bucket per env (`backups-<env_name>`). Layout: `velero/` for cluster + PV backups, `etcd/` for raw etcd snapshots.

**One-time prerequisite.** Hetzner Object Storage S3 access keys aren't yet creatable via the `hcloud` Terraform provider. Generate them once in the Hetzner Console (Project → Security → Object Storage) and export:

```sh
export HCLOUD_S3_ACCESS_KEY=...
export HCLOUD_S3_SECRET_KEY=...
```

The bucket itself is created by `37-velero` via the `aminueza/minio` Terraform provider pointed at Hetzner's S3 endpoint — no manual bucket setup needed. (Migrating these creds to SOPS is on the M2 list.)

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
