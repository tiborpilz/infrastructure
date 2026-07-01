locals {
  hcloud_csi_namespace = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = "hcloud-csi"
      labels = {
        "pod-security.kubernetes.io/enforce" = "privileged"
        "pod-security.kubernetes.io/audit"   = "privileged"
        "pod-security.kubernetes.io/warn"    = "privileged"
      }
    }
  }

  hcloud_ccm_secret = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata   = { name = "hcloud", namespace = "kube-system" }
    data = {
      token   = base64encode(var.hcloud_token)
      network = base64encode(var.network_name)
    }
  }

  hcloud_csi_secret = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata   = { name = "hcloud", namespace = "hcloud-csi" }
    data       = { token = base64encode(var.hcloud_token) }
  }

  hcloud_csi_values = yamlencode({
    storageClasses = [
      {
        name          = "hcloud-volumes"
        isDefault     = true
        reclaimPolicy = "Delete"
      }
    ]
    node = {
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [{
              matchExpressions = [
                { key = "instance.hetzner.cloud/is-root-server", operator = "NotIn", values = ["true"] },
                { key = "instance.hetzner.cloud/provided-by", operator = "NotIn", values = ["robot"] },
                { key = "node.tibor.sh/tier", operator = "NotIn", values = ["proxmox"] },
              ]
            }]
          }
        }
      }
    }
  })

  hcloud_manifests = [
    { name = "ns-hcloud-csi", contents = yamlencode(local.hcloud_csi_namespace) },
    { name = "hcloud-ccm-secret", contents = yamlencode(local.hcloud_ccm_secret) },
    { name = "hcloud-ccm", contents = data.helm_template.hcloud_ccm.manifest },
    { name = "hcloud-csi-secret", contents = yamlencode(local.hcloud_csi_secret) },
    { name = "hcloud-csi", contents = data.helm_template.hcloud_csi.manifest },
  ]
}

data "helm_template" "hcloud_csi" {
  name         = "hcloud-csi"
  namespace    = "hcloud-csi"
  repository   = "https://charts.hetzner.cloud"
  chart        = "hcloud-csi"
  version      = var.hcloud_csi_chart_version
  kube_version = var.kubernetes_version

  values = [local.hcloud_csi_values]
}

data "helm_template" "hcloud_ccm" {
  name         = "hcloud-cloud-controller-manager"
  namespace    = "kube-system"
  repository   = "https://charts.hetzner.cloud"
  chart        = "hcloud-cloud-controller-manager"
  version      = var.hcloud_ccm_version
  kube_version = var.kubernetes_version

  set {
    name  = "networking.enabled"
    value = "true"
  }

}

