cloudProvider: hetzner

# Hetzner CAS does not support label-based auto-discovery; node groups are
# enumerated explicitly via --nodes (below). clusterName is set only because
# the chart's deployment.yaml is gated on one of autoDiscovery.clusterName /
# .namespace / .labels / autoscalingGroups being truthy — for hetzner it is
# otherwise ignored.
autoDiscovery:
  clusterName: "${cluster_name}"

extraArgs:
  v: 4
  cloud-provider: hetzner
  # Pool selection: `least-waste` picks the pool whose template node leaves
  # the least slack after fitting the pending pod. Small pods land on the
  # cheap tier, fat pods land on the large tier.
  expander: "least-waste"
  # Chart trick: `extraArgs` keys must be unique, but the deployment template
  # strips anything after the first underscore before rendering the flag
  # name. So `nodes_<tier>` keys all render as `--nodes=...` — one per pool.
%{ for pool in pools ~}
  nodes_${pool.name}: "${pool.min}:${pool.max}:${pool.instance_type}:${pool_location}:${pool.name}"
%{ endfor ~}
  # Scale-down tuning. Reactivity over thrift: scale up fast on Pending pods,
  # scale down once unneeded for 5m. Adjust if CI bursts are bursty enough
  # that nodes flap.
  scale-down-enabled: "true"
  scale-down-delay-after-add: "5m"
  scale-down-unneeded-time: "5m"
  scale-down-utilization-threshold: "0.5"
  # Skip-checks: by default CAS won't remove a node with system pods or local
  # storage. On this cluster, system DaemonSets land everywhere; local storage
  # (longhorn) is fine to be drained off a burst node.
  skip-nodes-with-system-pods: "false"
  skip-nodes-with-local-storage: "false"
  # Talos VMs have no shell; if a new node hasn't joined within this window
  # the autoscaler deletes it and tries again. Talos boot + kubelet register
  # takes ~2–3 minutes from cold; 8m leaves headroom for slow Hetzner regions.
  max-node-provision-time: "8m"
  unremovable-node-recheck-timeout: "2m"

# Static cluster env (image, network, firewall) is non-secret; rotated by
# bumping the cluster module. Token + cloud-init are sensitive — those come
# from the Secret managed by Terraform.
extraEnv:
  HCLOUD_IMAGE: "${hcloud_image_id}"
  HCLOUD_NETWORK: "${hcloud_network_id}"
%{ if hcloud_firewall_id != "" ~}
  HCLOUD_FIREWALL: "${hcloud_firewall_id}"
%{ endif ~}

envFromSecret: "${secret_name}"

rbac:
  serviceAccount:
    create: true
    name: cluster-autoscaler

resources:
  requests:
    cpu: 50m
    memory: 100Mi
  limits:
    cpu: 200m
    memory: 300Mi

# Run the autoscaler itself on the static baseline so a botched scale-down
# can't take out its own pod. The control plane has the room; workloads on it
# tolerate the control-plane taint via `allowSchedulingOnControlPlanes`.
tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule

# Chart convention: `securityContext` → pod spec, `containerSecurityContext`
# → container spec.
securityContext:
  runAsNonRoot: true
  runAsUser: 65534
  fsGroup: 65534
  seccompProfile:
    type: RuntimeDefault

containerSecurityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]
