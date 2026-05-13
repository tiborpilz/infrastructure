# metrics-server Helm values, templated by Terragrunt.
# Chart: https://github.com/kubernetes-sigs/metrics-server/tree/master/charts/metrics-server

# Single-replica is fine on a single-node-ish cluster; bump to 2 once you
# have multiple workers and want HA scraping.
replicas: 1

# Talos's kubelet serves its `/metrics/resource` endpoint with a self-signed
# cert by default. metrics-server's default behavior is to verify, so without
# this flag the scrape fails with `x509: cannot validate certificate`. The
# proper fix is configuring Talos to issue kubelet-serving certs from a known
# CA — overkill for a homelab where the traffic is in-cluster anyway.
#
# `args` is additive to the chart's `defaultArgs`, so the standard
# --cert-dir / --kubelet-preferred-address-types / --metric-resolution
# flags are still applied.
args:
  - --kubelet-insecure-tls

# Modest reservations; metrics-server scales sub-linearly with node count and
# is cheap for a small cluster.
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 200Mi

# kube-system already has the right PodSecurity labels for metrics-server's
# pod spec; ours doesn't, but metrics-server's pod doesn't require anything
# beyond `restricted`, so no PSA exception needed.
