# `velero` module — backups + Talos etcd snapshots

Brings the cluster from "no off-node backup" to "scheduled cluster-state and PV backups, plus etcd snapshots, all uploaded to Hetzner Object Storage." Single layer; one bucket; two backup paths.

## What this layer does

1. **Hetzner Object Storage bucket** — created via the `aws` Terraform provider pointed at Hetzner's S3 endpoint. Single bucket (`backups-<env>`) with two prefixes:
   - `velero/` — Velero backup data + metadata
   - `etcd/` — Talos etcd snapshots
2. **Velero (Kopia file-system backup)** — Argo CD Application installs `vmware-tanzu/velero`. The node-agent walks PV file systems and uploads to S3. No `VolumeSnapshotClass`, no upstream `volume-snapshot-controller` — the simplest moving-part footprint that still covers PVs end-to-end.
3. **Daily backup schedule** — defined in the Helm values. 14-day TTL.
4. **Talos etcd snapshot CronJob** — runs every 6 hours in the `cluster-backup` namespace. `talosctl etcd snapshot` writes locally; `aws s3 cp` uploads to `etcd/`. Old objects are tail-pruned after `var.etcd_snapshot_retention_days`.
5. **Readiness gate** — `terraform_data` waits on Argo CD's health for Velero and on the CronJob existing.

## What this layer does NOT do

- **Bucket creation prerequisites.** Hetzner Object Storage S3 access keys are NOT yet creatable via the `hcloud` Terraform provider. The operator generates them once in the Hetzner Console; this module reads them from `HCLOUD_S3_ACCESS_KEY` / `HCLOUD_S3_SECRET_KEY`.
- **CSI volume snapshots.** Defer until HA milestone; Kopia covers PVs for now.
- **Restore drills.** Manual quarterly drill is on the operator's calendar. `velero` CLI is in the dev shell for this.
- **Prometheus metrics / alerts on backup failure.** Wait for the observability layer in M2.
- **Custom etcd-snapshotter image.** Uses a pinned community `talosctl + aws-cli` image. Build our own and push to the platform registry once `zot` is up.

## Inputs

See `variables.tf`. Required:

- Cluster connection material (`kubernetes_host`, `cluster_ca_certificate`, `client_certificate`, `client_key`)
- `kubeconfig_path` for the local-exec readiness wait
- `talosconfig_raw` (from `10-cluster`) — mounted into the etcd CronJob
- `talos_cp_endpoints` (from `10-cluster`) — currently informational; the CronJob talks to `127.0.0.1:50000` via `hostNetwork`
- `hcloud_object_storage_region` (e.g. `fsn1`) and S3 access/secret keys
- `bucket_name` — convention `backups-<env>`
- `velero_values` — rendered Helm values

## Outputs

- `bucket_name`, `velero_namespace`, `velero_chart_version`
- `ready` — boolean sentinel, same convention as `platform-data`

## Notes

- **Why one bucket, not two?** PLAN.md describes the layout as `backups-<env>/velero/` and `backups-<env>/etcd/` — those are object-key prefixes, not separate buckets. One bucket is cheaper, less paperwork, and Velero's Backup Storage Location accepts a `prefix` field natively.
- **Why `aws` provider?** It's the best-supported S3 client in the Terraform registry; the name is misleading. All AWS-specific lookups (STS, account ID, IMDS) are disabled in `providers.tf`.
- **Why `hostNetwork: true` on the etcd CronJob?** Talos's API listens on `0.0.0.0:50000` on every node. Using `hostNetwork` lets the pod dial `127.0.0.1:50000` regardless of which CP node it lands on — no IP coordination needed for HA. The cluster-backup namespace is labelled `pod-security.kubernetes.io/enforce=privileged` to allow this.
- **Why a separate namespace for the CronJob?** Velero pods and the etcd snapshotter have unrelated blast radii. Co-locating them would couple their RBAC and PSS posture for no benefit.
- **Restore drill** (PLAN.md: untested backups are not backups):
  ```sh
  velero backup create smoke-$(date +%s) --include-namespaces smoke-restore --wait
  kubectl delete ns smoke-restore
  velero restore create --from-backup smoke-... --wait
  ```
- **Idempotency.** Re-running `terragrunt apply` is a no-op: `terraform_data.velero_ready` only re-executes if the underlying Application or CronJob UID changes.
