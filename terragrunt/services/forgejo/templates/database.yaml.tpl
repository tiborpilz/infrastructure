apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: forgejo-db
spec:
  instances: 1
  imageName: ghcr.io/cloudnative-pg/postgresql:17.2
  storage:
    size: ${pg_storage_size}
    storageClass: ${storage_class}
  bootstrap:
    initdb:
      database: forgejo
      owner: forgejo
  monitoring:
    enablePodMonitor: false
