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
  monitoring:
    enablePodMonitor: false
