# hcloud-csi Helm values, templated by Terragrunt.
# Chart: https://github.com/hetznercloud/csi-driver/tree/main/charts/hcloud-csi
#
# The chart auto-creates the `hcloud-volumes` StorageClass and reads the
# `hcloud` Secret from kube-system (already provisioned by 20-argocd for the
# CCM, key `token`). Nothing else is required for a single-node PoC.

storageClasses:
  - name: hcloud-volumes
    defaultStorageClass: true
    reclaimPolicy: Retain
    extraParameters:
      csi.storage.k8s.io/fstype: ext4

# Single-node PoC — one controller replica is enough.
controller:
  replicaCount: 1
