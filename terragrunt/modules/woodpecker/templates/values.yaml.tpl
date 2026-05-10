agent:
  enabled: true
  replicaCount: 1
  extraSecretNamesForEnvFrom:
    - woodpecker-secrets
  env:
    WOODPECKER_SERVER: woodpecker-server:9000
    WOODPECKER_BACKEND: kubernetes
    WOODPECKER_BACKEND_K8S_NAMESPACE: woodpecker
    WOODPECKER_BACKEND_K8S_STORAGE_CLASS: ${storage_class}
    WOODPECKER_BACKEND_K8S_VOLUME_SIZE: ${pipeline_volume_size}
    WOODPECKER_BACKEND_K8S_STORAGE_RWX: false
    WOODPECKER_CONNECT_RETRY_COUNT: "5"
  persistence:
    enabled: true
    size: ${agent_data_size}
    storageClass: ${storage_class}

server:
  enabled: true
  createAgentSecret: true
  extraSecretNamesForEnvFrom:
    - woodpecker-secrets
  env:
    WOODPECKER_HOST: ${woodpecker_url}
    WOODPECKER_ADMIN: ${woodpecker_admins}
    WOODPECKER_OPEN: false
    WOODPECKER_FORGEJO: true
    WOODPECKER_FORGEJO_URL: ${forgejo_url}
  persistentVolume:
    enabled: true
    size: ${server_data_size}
    storageClass: ${storage_class}
  service:
    type: ClusterIP
    port: 80
  ingress:
    enabled: false
