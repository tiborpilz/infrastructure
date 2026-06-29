locals {
  cilium_values = yamlencode({
    ipam = {
      mode = "kubernetes"
    }

    kubeProxyReplacement = true

    k8sServiceHost = "localhost"
    k8sServicePort = 7445

    gatewayAPI = {
      enabled = true
    }

    defaultLBServiceIPAM = "none"

    hubble = {
      relay = { enabled = true }
      ui    = { enabled = true }
    }

    operator = {
      replicas = 1
    }

    cgroup = {
      autoMount = { enabled = false }
      hostRoot  = "/sys/fs/cgroup"
    }

    securityContext = {
      capabilities = {
        ciliumAgent = [
          "CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK",
          "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER",
          "SETGID", "SETUID",
        ]
        cleanCiliumState = [
          "NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE",
        ]
      }
    }
  })

  cilium_manifests = [
    { name = "cilium", contents = data.helm_template.cilium.manifest },
  ]
}

data "helm_template" "cilium" {
  name         = "cilium"
  namespace    = "kube-system"
  repository   = "https://helm.cilium.io"
  chart        = "cilium"
  version      = var.cilium_chart_version
  kube_version = var.kubernetes_version

  values = [local.cilium_values]
}
