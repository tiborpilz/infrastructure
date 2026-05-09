# Velero Helm values, templated by Terragrunt.
# Chart: https://github.com/vmware-tanzu/helm-charts/tree/main/charts/velero
#
# Single-node PoC. Kopia file-system backup (no CSI snapshots), Hetzner Object
# Storage as the backend, daily schedule with 14-day retention.

# velero-plugin-for-aws is loaded as an init container; it handles any
# S3-compatible backend including Hetzner Object Storage.
initContainers:
  - name: velero-plugin-for-aws
    image: velero/velero-plugin-for-aws:v1.10.0
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - name: plugins
        mountPath: /target

# S3 credentials come from a TF-managed Secret (see modules/velero/main.tf).
# Key `cloud` holds an AWS-credentials-file body.
credentials:
  useSecret: true
  existingSecret: velero-s3-credentials

configuration:
  # Kopia (file-system backup) — no upstream snapshot-controller required.
  uploaderType: kopia

  # All Pods get their volumes backed up by default. Apps that explicitly
  # don't want this set the `backup.velero.io/backup-volumes-excludes`
  # annotation on the Pod spec template.
  defaultVolumesToFsBackup: true

  backupStorageLocation:
    - name: default
      provider: aws
      bucket: ${bucket_name}
      prefix: velero
      default: true
      config:
        region: ${region}
        s3ForcePathStyle: "true"
        s3Url: https://${region}.your-objectstorage.com

  # Kopia handles PV backups directly. Volume snapshot locations stay empty
  # until we add CSI snapshot support at the HA milestone.
  volumeSnapshotLocation: []

# Required for Kopia file-system backup. The node-agent DaemonSet runs on
# every node and walks Pod volumes via /var/lib/kubelet/pods (Talos default).
deployNodeAgent: true
nodeAgent:
  podVolumePath: /var/lib/kubelet/pods

# Daily backup at 02:00 cluster time, 14-day TTL — matches PLAN.md.
schedules:
  daily:
    disabled: false
    schedule: "0 2 * * *"
    useOwnerReferencesInBackup: false
    template:
      ttl: "336h0m0s"
      includedNamespaces:
        - "*"
      storageLocation: default
      snapshotMoveData: false

# No Prometheus stack yet (M2). Re-enable when observability lands.
metrics:
  enabled: false
