# authentik Helm values — base structure only.
#
# `additionalObjects` (CNPG Cluster + Valkey Service/StatefulSet) is appended
# in the Terraform module via yamldecode/yamlencode, because the chart treats
# each item as a structured object (`toYaml`-then-`tpl`) — passing them as
# block-scalar strings here would render them as bare strings, not k8s objects.
#
# Chart: https://github.com/goauthentik/helm/tree/main/charts/authentik

global:
  # Talos enforces baseline PSS by default and audits/warns on restricted.
  # Set pod-level security context to comply with `restricted` so we don't
  # have to relax the namespace label.
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault

  # The bootstrap Secret carries every AUTHENTIK_* env the chart would
  # otherwise have rendered into its own Secret from `authentik.*` values.
  # That rendering is skipped because we set `existingSecret.secretName`
  # below, so the bootstrap Secret has to be self-sufficient for everything
  # except the PG password (which CNPG generates).
  envFrom:
    - secretRef:
        name: authentik-bootstrap

  # PG password is the only runtime value not in our bootstrap Secret — it
  # comes from CNPG's auto-generated `<cluster>-app` Secret. CNPG manages
  # rotation; we reference whatever it currently holds.
  env:
    - name: AUTHENTIK_POSTGRESQL__PASSWORD
      valueFrom:
        secretKeyRef:
          name: authentik-db-app
          key: password

authentik:
  # `existingSecret` covers AUTHENTIK_SECRET_KEY. When set, all `authentik.*`
  # secret-derived values are ignored. PG host/user/db/port and Redis host
  # are therefore set as env vars in the bootstrap Secret, NOT here.
  existingSecret:
    secretName: authentik-bootstrap

server:
  replicas: 1
  ingress:
    # Gateway API replaces this — HTTPRoute is created by the Terraform
    # module alongside the Application.
    enabled: false
  # Container-level security context for `restricted` PSS compliance.
  containerSecurityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: false  # authentik writes to /tmp and /etc; runtime mounts handle it
    runAsNonRoot: true
    capabilities:
      drop: ["ALL"]
    seccompProfile:
      type: RuntimeDefault

worker:
  replicas: 1
  containerSecurityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: false
    runAsNonRoot: true
    capabilities:
      drop: ["ALL"]
    seccompProfile:
      type: RuntimeDefault

# Chart's bundled PostgreSQL is disabled — we use the CNPG Cluster instead.
postgresql:
  enabled: false
