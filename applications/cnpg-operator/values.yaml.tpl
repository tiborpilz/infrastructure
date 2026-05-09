# cloudnative-pg operator Helm values, templated by Terragrunt.
# Chart: https://github.com/cloudnative-pg/charts/tree/main/charts/cloudnative-pg
#
# CRDs ship with the chart. Single-node PoC, so one operator replica.

replicaCount: 1

# CNPG installs its CRDs as part of the chart. Argo CD applies them with
# ServerSideApply=true (set on the Application syncPolicy) because the
# Cluster CRD exceeds the 256 KiB client-side annotation limit.
crds:
  create: true

# Operator only — no monitoring stack until Prometheus arrives in M2.
monitoring:
  podMonitorEnabled: false
