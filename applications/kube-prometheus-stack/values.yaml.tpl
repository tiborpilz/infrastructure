# kube-prometheus-stack values, templated by Terragrunt.
# Chart: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack

# CRDs ship with the chart and are applied via SSA at the Application level.
crds:
  enabled: true

# Override chart fullname so every operator-derived object name (Prometheus
# CR, Alertmanager CR, StatefulSet, PVC) builds from this short string
# instead of `<release>-<chart-name>` which produces 80+ char PVC names
# that exceed Hetzner's 64-char label-value limit.
#
# `prometheus.name` / `alertmanager.name` look like the right knobs but
# don't actually work in v67.x — the CR name still falls through to
# fullname. fullnameOverride is the only lever that propagates.
fullnameOverride: kps

# Strip the chart prefix from operator-managed object names too.
cleanPrometheusOperatorObjectNames: true

# ---------------------------------------------------------------------------
# Grafana — uses Authentik OIDC natively (no oauth2-proxy hop).
# Client credentials come in as env vars via envFromSecret = "grafana-oidc";
# grafana.ini interpolates them with $__env{...}.
# ---------------------------------------------------------------------------
grafana:
  enabled: true
  defaultDashboardsEnabled: true

  # Mount the TF-managed Secret as env vars (GF_AUTH_GENERIC_OAUTH_CLIENT_ID
  # and GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET).
  envFromSecret: grafana-oidc

  persistence:
    enabled: true
    size: 5Gi
    storageClassName: ${storage_class}

  service:
    type: ClusterIP
    port: 80

  podAnnotations:
    # Force a pod restart whenever the OIDC client secret rotates so Grafana
    # picks up the new env value immediately.
    checksum/grafana-oidc: ${oidc_secret_checksum}

  grafana.ini:
    server:
      root_url: ${grafana_url}
      # Required when behind a reverse proxy (the Gateway). Without it,
      # Grafana builds OAuth redirect URLs from request headers and breaks.
      domain: ${grafana_hostname}

    auth:
      # Leave the local login form for break-glass; admin can `grafana-cli`
      # exec in to reset if Authentik is down. Set to true once you're sure
      # OIDC is reliable.
      disable_login_form: false
      oauth_auto_login: false

    "auth.generic_oauth":
      enabled: true
      name: Authentik
      allow_sign_up: true
      client_id: $__env{GF_AUTH_GENERIC_OAUTH_CLIENT_ID}
      client_secret: $__env{GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET}
      scopes: openid profile email groups
      auth_url: ${authentik_url}/application/o/authorize/
      token_url: ${authentik_url}/application/o/token/
      api_url: ${authentik_url}/application/o/userinfo/
      # JMESPath against the userinfo claims. Falls through to '' when no
      # admin group matches — Grafana's strict role mode then rejects login.
      # Adjust the role mapping if you want non-admin Viewer access too.
      role_attribute_path: ${role_attribute_path}
      role_attribute_strict: true
      allow_assign_grafana_admin: true
      use_pkce: true

    users:
      # Auto-create users from OIDC on first login; their role is computed
      # by role_attribute_path above.
      auto_assign_org: true
      auto_assign_org_role: Viewer

# ---------------------------------------------------------------------------
# Prometheus — cluster-internal. Port-forward when needed; no HTTPRoute.
# ---------------------------------------------------------------------------
prometheus:
  prometheusSpec:
    retention: 15d
    # serviceMonitorSelector{,NilUsesHelmValues}: by default the operator
    # only scrapes ServiceMonitors with helm-chart-specific labels. Setting
    # this to false lets it pick up any ServiceMonitor anywhere — what you
    # actually want.
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    probeSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: ${storage_class}
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 20Gi
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: "1"
        memory: 1500Mi

# ---------------------------------------------------------------------------
# Alertmanager — also cluster-internal. Configure receivers later when an
# actual alerting workflow exists.
# ---------------------------------------------------------------------------
alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: ${storage_class}
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 2Gi
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 200m
        memory: 256Mi

# ---------------------------------------------------------------------------
# node-exporter — DaemonSet with hostNetwork. The observability namespace
# is labelled `privileged` so it can run here.
# ---------------------------------------------------------------------------
prometheus-node-exporter:
  hostRootFsMount:
    enabled: true
  resources:
    requests:
      cpu: 20m
      memory: 32Mi
    limits:
      cpu: 100m
      memory: 64Mi
