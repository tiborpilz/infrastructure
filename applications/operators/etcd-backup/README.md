# etcd-backup

Scheduled etcd snapshots for the single-node control plane. With one etcd
member there is no quorum to fall back on, so an off-node backup is the only
recovery path if the control-plane node or its disk is lost.

## How it works

[`talos-backup`](https://github.com/siderolabs/talos-backup) runs as a 6-hourly
CronJob: it takes a consistent etcd snapshot via the Talos API, age-encrypts
it, and pushes it to an S3 bucket.

- **Auth** — a `talos.dev` ServiceAccount (`talos-etcd-backup`) scoped to
  `os:etcd:backup`. Talos materialises a Secret the pod mounts at
  `/var/run/secrets/talos.dev`; this needs `machine.features.kubernetesTalosAPIAccess`
  on the control plane, set in `terragrunt/cluster/talos/main.tf`.
- **Storage** — an `ObjectBucketClaim` provisions a bucket on the Ceph object
  store, on the Proxmox OSD tier — a different failure domain from the Hetzner
  control plane. Rook hands the CronJob the bucket name and keys via a
  ConfigMap + Secret.
- **Encryption** — snapshots are encrypted to the age recipient in
  `manifests/cronjob.yaml` (the `.sops.yaml` YubiKey identity by default); the
  matching private key is needed to restore.

## Restore

```sh
# fetch the newest .age snapshot from the bucket (mc/aws/rclone against the RGW), then:
age -d -i <your-age-identity> -o db.snapshot <snapshot>.age
talosctl bootstrap --recover-from=./db.snapshot
```

Full procedure: Talos [disaster recovery guide](https://www.talos.dev/latest/advanced/disaster-recovery/).

## Before it runs

- Apply the Terraform change so `kubernetesTalosAPIAccess` is live (the
  `serviceaccounts.talos.dev` CRD appears with it).
- Pin the `talos-backup` image — `manifests/cronjob.yaml` uses `:latest`.

The bucket is in-cluster, so it covers control-plane node/disk loss and etcd
corruption but not total-cluster loss; replicate off-site for that.
