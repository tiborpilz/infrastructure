# `platform-data` module — CSI + CNPG operator

Brings the cluster from "no persistent storage, no DB operator" to "stateful workloads can declare what they need". Two Argo CD Applications, one readiness gate.

## What this layer does

1. **hcloud-csi** — Argo CD Application that installs the Hetzner Cloud CSI driver. Creates the `hcloud-volumes` StorageClass. Reuses the `hcloud` Secret in `kube-system` (already created by `20-argocd` for the CCM) — no extra wiring.
2. **cloudnative-pg** — Argo CD Application that installs the CNPG operator + its CRDs (`Cluster.postgresql.cnpg.io`, `Pooler`, `Backup`, etc.). Watches CRs cluster-wide.
3. **Readiness gate** — `terraform_data` with a `local-exec` that waits for both Argo CD Applications to become Healthy, the StorageClass to exist, and the operator Deployment to be Available. Downstream layers depend on this.

## What this layer does NOT do

- No Postgres `Cluster` CRs. Each consuming app declares its own (e.g., `40-authentik` declares `authentik-cluster`).
- No Valkey/Redis. authentik inlines its Valkey StatefulSet directly because the operator ecosystem isn't mature; future stateful apps that need Redis-compatible storage will follow the same pattern until something changes.
- No backup configuration for CNPG. Defer until `Velero` or an S3 endpoint is wired up.

## Inputs

See `variables.tf`. Required: cluster connection material (`kubernetes_host`, `cluster_ca_certificate`, `client_certificate`, `client_key`), `kubeconfig_path` (for the local-exec waits), and the rendered Helm values strings (`hcloud_csi_values`, `cnpg_values`).

## Outputs

- `storage_class` — `hcloud-volumes`. Pass into Cluster CRs.
- `cnpg_namespace` — `cnpg-system`. Mostly informational.
- `ready` — boolean sentinel. Downstream layers read this in `dependency.platform_data.outputs.ready` to gate their apply on the readiness wait.

## Why two charts, not one

They have different release cadences and unrelated blast radii. Folding them into a single Argo CD Application would couple a CSI driver upgrade to a database operator upgrade, which is silly.

## Notes

- **CRD installation:** the CNPG chart bundles its CRDs. `ServerSideApply=true` is set on the Argo CD Application's syncPolicy because `Cluster.postgresql.cnpg.io` exceeds the 256 KiB annotation limit that client-side apply imposes.
- **Why a `terraform_data` wait, not a kubectl_manifest dependency chain?** The downstream layer (`40-authentik`) declares its `Cluster.postgresql.cnpg.io` CR via the authentik chart's `additionalObjects`. That CR is rendered by Argo CD, not by Terraform — so a TF resource dependency wouldn't catch the "operator not yet running" race. The local-exec wait does.
- **PoC sizing:** the hcloud-csi default volume type is HC's standard SSD. €0.04/GB/month. A 10 GiB volume costs ~€0.40/month.
