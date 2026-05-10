storageClass: ${storage_class}

database:
  storageSize: ${pg_storage_size}

test:
  enabled: false

global:
  storageClass: ${storage_class}

namespaceOverride: forgejo

persistence:
  enabled: true
  create: true
  mount: true
  claimName: forgejo-data
  size: ${forgejo_data_size}
  storageClass: ${storage_class}

ingress:
  enabled: false

httpRoute:
  enabled: true
  parentRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: ${gateway_name}
      namespace: ${gateway_namespace}
  hostnames:
    - ${hostname}
  matches:
    path:
      type: PathPrefix
      value: /
    timeouts: {}
  port: 3000
  terminate: true

tcpRoute:
  enabled: false

service:
  http:
    type: ClusterIP
    port: 3000
  ssh:
    type: ClusterIP

gitea:
  admin:
    existingSecret: forgejo-admin
    email: ${admin_email}
    passwordMode: keepUpdated

  oauth:
    - name: authentik
      provider: openidConnect
      existingSecret: forgejo-oidc
      autoDiscoverUrl: ${oidc_discovery_url}

  podAnnotations:
    checksum/forgejo-admin-secret: ${admin_secret_checksum}
    checksum/forgejo-oidc-secret: ${oidc_secret_checksum}

  config:
    APP_NAME: Forgejo
    server:
      DOMAIN: ${hostname}
      ROOT_URL: ${forgejo_url}/
      PROTOCOL: http
      HTTP_PORT: 3000
      SSH_DOMAIN: ${hostname}
      DISABLE_SSH: true
      START_SSH_SERVER: false
    database:
      DB_TYPE: postgres
      HOST: forgejo-db-rw:5432
      NAME: forgejo
      USER: forgejo
      SCHEMA: public
    oauth2_client:
      ENABLE_AUTO_REGISTRATION: true
      OPENID_CONNECT_SCOPES: email profile
    openid:
      ENABLE_OPENID_SIGNIN: false
      ENABLE_OPENID_SIGNUP: false
    service:
      DISABLE_REGISTRATION: true
      ALLOW_ONLY_EXTERNAL_REGISTRATION: true
      SHOW_REGISTRATION_BUTTON: false
      ENABLE_INTERNAL_SIGNIN: true
      ENABLE_BASIC_AUTHENTICATION: true
    packages:
      ENABLED: false

  additionalConfigFromEnvs:
    - name: FORGEJO__DATABASE__PASSWD
      valueFrom:
        secretKeyRef:
          name: forgejo-db-app
          key: password
