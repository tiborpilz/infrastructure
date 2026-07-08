# etcd-backup

Scheduled etcd snapshots for the single-node control plane. With one etcd
member there is no quorum to fall back on, so an off-node backup is the only
recovery path if the control-plane node or its disk is lost.

## How it works

[`talos-backup`](https://github.com/siderolabs/talos-backup) runs as a CronJob
(every 6 hours). It calls the Talos API for a consistent etcd snapshot,
age-encrypts it, and pushes it to an S3 bucket.

- **Auth** — a `talos.dev` `ServiceAccount` (`talos-etcd-backup`) scoped to the
  `os:etcd:backup` role. Talos materialises a Secret the pod mounts at
  `/var/run/secrets/talos.dev`. This requires
  `machine.features.kubernetesTalosAPIAccess` on the control plane, which is
  set in Terraform (`terragrunt/cluster/talos/main.tf`) and gated to this
  namespace and role.
- **Storage** — an `ObjectBucketClaim` (`ceph-bucket` class) provisions a
  bucket on the Ceph object store. Rook drops a ConfigMap + Secret named
  `etcd-backup` with the bucket name and access keys, which the CronJob reads.
  The bucket lives on the Ceph OSDs on the **Proxmox** tier — a different
  failure domain from the Hetzner control plane, so losing the CP node does
  not lose its backups.
- **Encryption** — snapshots are encrypted to the `AGE_RECIPIENT_PUBLIC_KEY`
  in `manifests/cronjob.yaml` (currently the YubiKey identity from
  `.sops.yaml`). You need the matching private key to restore.

## Before this works

1. Apply the Terraform change so `kubernetesTalosAPIAccess` is live on the
   control plane (the `serviceaccounts.talos.dev` CRD appears once it is).
2. Pin the container image — `manifests/cronjob.yaml` uses `:latest`; replace
   it with a released tag from `ghcr.io/siderolabs/talos-backup`.
3. Confirm the age recipient is a key you actually hold offline.

## Restore

```sh
# 1. Pull the newest snapshot from the bucket (mc/aws/rclone against the RGW).
# 2. Decrypt it:
age -d -i <your-age-identity> -o db.snapshot <snapshot>.age
# 3. Recover the control plane from it:
talosctl bootstrap --recover-from=./db.snapshot
```

See the Talos [disaster recovery guide](https://www.talos.dev/latest/advanced/disaster-recovery/)
for the full procedure.

## Caveat

The bucket is in-cluster (Ceph). This covers the likely failures — control-plane
node/disk loss or etcd corruption while the rest of the cluster survives. It
does **not** cover total-cluster loss; for that, replicate the bucket off-site
(talos-backup can target any S3 endpoint, so a second CronJob or bucket
replication to external object storage is the follow-up).
