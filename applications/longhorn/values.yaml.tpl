# Longhorn Helm values, templated by Terragrunt.
# Chart: https://github.com/longhorn/charts/tree/master/charts/longhorn

# ---------------------------------------------------------------------------
# Disable the pre-upgrade Job. It's a Helm pre-upgrade hook that references
# the chart's `longhorn-service-account`, but Argo CD applies the hook
# BEFORE the chart's regular resources (including that SA), causing the
# Job to crashloop with `serviceaccount "longhorn-service-account" not
# found`. Disabling the Job is the documented workaround for ArgoCD users.
# Preflight checks (iscsiadm/kernel modules) are still run by Longhorn at
# DaemonSet startup time, so we don't lose validation.
# ---------------------------------------------------------------------------
preUpgradeChecker:
  jobEnabled: false
  upgradeVersionCheck: false

# ---------------------------------------------------------------------------
# Default settings — apply to the cluster-wide Longhorn config.
# ---------------------------------------------------------------------------
defaultSettings:
  # Talos's writable filesystem path. Default `/var/lib/longhorn` works on
  # Talos because /var is writable.
  defaultDataPath: /var/lib/longhorn

  # Single worker today, so single replica. Bump to 3 once the cluster has
  # 3+ workers and re-replicate existing volumes via the Longhorn UI.
  defaultReplicaCount: 1

  # On a single-node cluster, the soft anti-affinity tries to spread
  # replicas across nodes and fails — disable so replicas can co-locate.
  replicaSoftAntiAffinity: true

  # Don't overcommit storage. 100% = honest reporting; 200% (the default)
  # lets you provision more than physically available, which is fine in HA
  # setups but misleading on a single node.
  storageOverProvisioningPercentage: 100

  # Reserve 10% of disk for Talos / system. The default 30% is too
  # aggressive on small Hetzner instances.
  storageMinimalAvailablePercentage: 10

# ---------------------------------------------------------------------------
# StorageClass settings — keep Longhorn OPT-IN (don't override hcloud-volumes
# as cluster default).
# ---------------------------------------------------------------------------
persistence:
  defaultClass: false
  defaultClassReplicaCount: 1
  reclaimPolicy: Delete
  # Volume binding mode WaitForFirstConsumer means Longhorn picks the node
  # based on where the pod gets scheduled — important for affinity-pinned
  # workloads.
  defaultDataLocality: best-effort

# ---------------------------------------------------------------------------
# Ingress — disabled; UI is port-forward only by default.
# ---------------------------------------------------------------------------
ingress:
  enabled: false
service:
  ui:
    type: ClusterIP

# ---------------------------------------------------------------------------
# Resources — modest. The DaemonSet doesn't run heavy workloads itself; the
# actual data movement happens in per-volume engine pods.
# ---------------------------------------------------------------------------
longhornManager:
  priorityClass: system-cluster-critical

longhornDriver:
  priorityClass: system-cluster-critical
