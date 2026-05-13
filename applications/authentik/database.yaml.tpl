apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: authentik-db
spec:
  instances: 1
  imageName: ghcr.io/cloudnative-pg/postgresql:17.2
  storage:
    size: ${pg_storage_size}
    storageClass: ${storage_class}
  bootstrap:
    initdb:
      database: authentik
      owner: authentik
  # No backup config yet — Velero/S3 lands in a later milestone. CNPG will
  # still take WAL archives locally on the PG pod's PV; that survives pod
  # restarts on the same node but not node loss.
  monitoring:
    enablePodMonitor: false
