image:
  repository: ghcr.io/siderolabs/omni

replicaCount: 1

# Omni binds the WireGuard interface and needs NET_ADMIN. Talos grants it
# without hostNetwork, so we leave hostNetwork off and rely on a NodePort
# Service (default 30180/UDP) for the public SideroLink listener.
hostNetwork: false
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    add: ["NET_ADMIN"]
    drop: ["ALL"]

persistence:
  enabled: true
  size: ${storage_size}
  storageClassName: ${storage_class}
  accessModes:
    - ReadWriteOnce

# Embedded etcd, encrypted with the GPG key materialised by TF into the
# `omni-etcd-gpg` Secret (chart wires this via etcdEncryptionKey.existingSecret).
config:
  account:
    name: ${account_name}
  storage:
    default:
      kind: etcd
      etcd:
        embedded: true
        embeddedDBPath: /data/etcd/
        privateKeySource: file:///omni.asc
  auth:
    # auth0.enabled defaults to true and the chart refuses to flip it back;
    # we have to set it false here so the OIDC provider is the only enabled
    # auth backend.
    auth0:
      enabled: false
    oidc:
      enabled: true
      scopes:
        - openid
        - profile
        - email
      # Authentik doesn't set email_verified on TF-provisioned users (no
      # verification flow ran). Authentik is the trusted IdP and has already
      # authenticated the session before issuing the JWT, so accepting the
      # email claim without the verified flag is OK in this setup.
      allowUnverifiedEmail: true
  services:
    api:
      advertisedURL: https://${omni_hostname}
    kubernetesProxy:
      advertisedURL: https://${k8s_proxy_hostname}
    machineAPI:
      advertisedURL: https://${siderolink_hostname}
    siderolink:
      joinTokensMode: strict
      wireGuard:
        # endpoint is the in-pod listen address; advertisedEndpoint (set in
        # main.tf) is what nodes dial in from the outside.
        endpoint: 0.0.0.0:50180

service:
  main:
    type: ClusterIP
    omniPort: 8080
    siderolinkApiPort: 8090
    # Cilium understands appProtocol on Service ports; the chart annotates
    # for Traefik h2c which Cilium ignores cleanly.
  k8sProxy:
    type: ClusterIP
    port: 8095
  wireguard:
    type: NodePort
    port: 50180
    nodePort: 30180

# All three public hostnames attach to the same public Gateway listener on
# `sectionName: https` (the wildcard cert is *.${domain}). UI + k8s proxy
# go through HTTPRoute; SideroLink Machine API uses GRPCRoute.
gatewayApi:
  ui:
    enabled: true
    hostnames:
      - ${omni_hostname}
    parentRefs:
      - group: gateway.networking.k8s.io
        kind: Gateway
        name: ${gateway_name}
        namespace: ${gateway_namespace}
        sectionName: https
  kubernetesProxy:
    enabled: true
    hostnames:
      - ${k8s_proxy_hostname}
    parentRefs:
      - group: gateway.networking.k8s.io
        kind: Gateway
        name: ${gateway_name}
        namespace: ${gateway_namespace}
        sectionName: https
  siderolinkApi:
    enabled: true
    hostnames:
      - ${siderolink_hostname}
    parentRefs:
      - group: gateway.networking.k8s.io
        kind: Gateway
        name: ${gateway_name}
        namespace: ${gateway_namespace}
        sectionName: https

ingress:
  main:
    enabled: false
  kubernetesProxy:
    enabled: false
  siderolinkApi:
    enabled: false
