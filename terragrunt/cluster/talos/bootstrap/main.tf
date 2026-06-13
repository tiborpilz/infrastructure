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

  hcloud_csi_values = yamlencode({
    storageClasses = [
      {
        name          = "hcloud-volumes"
        isDefault     = true
        reclaimPolicy = "Delete"
      }
    ]
  })
}

data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_version}/experimental-install.yaml"
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

data "helm_template" "argocd" {
  name         = "argocd"
  namespace    = "argocd"
  repository   = "https://argoproj.github.io/argo-helm"
  chart        = "argo-cd"
  version      = var.argocd_chart_version
  kube_version = var.kubernetes_version

  set {
    name  = "server.insecure"
    value = "true"
  }
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

data "helm_template" "hcloud_csi" {
  name         = "hcloud-csi"
  namespace    = "hcloud-csi"
  repository   = "https://charts.hetzner.cloud"
  chart        = "hcloud-csi"
  version      = var.hcloud_csi_chart_version
  kube_version = var.kubernetes_version

  values = [local.hcloud_csi_values]
}

data "helm_template" "cert_manager" {
  name         = "cert-manager"
  namespace    = "cert-manager"
  repository   = "https://charts.jetstack.io"
  chart        = "cert-manager"
  version      = var.cert_manager_chart_version
  kube_version = var.kubernetes_version

  set {
    name  = "crds.enabled"
    value = "true"
  }
}

data "helm_template" "external_dns" {
  name         = "external-dns"
  namespace    = "external-dns"
  repository   = "https://kubernetes-sigs.github.io/external-dns/"
  chart        = "external-dns"
  version      = var.external_dns_chart_version
  kube_version = var.kubernetes_version

  set {
    name  = "provider.name"
    value = "cloudflare"
  }

  set {
    name  = "env[0].name"
    value = "CF_API_TOKEN"
  }

  set {
    name  = "env[0].valueFrom.secretKeyRef.name"
    value = "cloudflare-api-token"
  }

  set {
    name  = "env[0].valueFrom.secretKeyRef.key"
    value = "token"
  }

  set {
    name  = "sources[0]"
    value = "service"
  }

  set {
    name  = "sources[1]"
    value = "gateway-httproute"
  }
}

