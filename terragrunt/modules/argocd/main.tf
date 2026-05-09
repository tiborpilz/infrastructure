locals {
  # Cilium and Hetzner CCM need the kube-apiserver host without scheme/port.
  apiserver_url_no_scheme = trimprefix(var.kubernetes_host, "https://")
  apiserver_host          = split(":", local.apiserver_url_no_scheme)[0]
}

# Gateway API CRDs. Cilium's gatewayAPI controller needs these in the cluster
# but does NOT install them itself. We fetch the official standard-install YAML
# from the gateway-api release and apply each document.
data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_version}/standard-install.yaml"

  request_headers = {
    Accept = "text/plain"
  }
}

data "kubectl_file_documents" "gateway_api_crds" {
  content = data.http.gateway_api_crds.response_body
}

resource "kubectl_manifest" "gateway_api_crds" {
  for_each = data.kubectl_file_documents.gateway_api_crds.manifests

  yaml_body         = each.value
  server_side_apply = true
}

# Hetzner Cloud token + network ID for the CCM. Stored in kube-system as a
# Secret the chart references via env.
resource "kubernetes_secret" "hcloud" {
  metadata {
    name      = "hcloud"
    namespace = "kube-system"
  }

  data = {
    token   = var.hcloud_token
    network = var.hcloud_network_id
  }
}

# Cilium — CNI, kube-proxy replacement, Hubble, Gateway API.
# Installed first so kubelet has a CNI plugin and pods can schedule.
resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.cilium_chart_version
  namespace  = "kube-system"

  values = [yamlencode({
    # KPR replaces kube-proxy entirely (Talos has proxy.disabled=true).
    kubeProxyReplacement = "true"
    k8sServiceHost       = local.apiserver_host
    k8sServicePort       = 6443

    # IPAM via Kubernetes node CIDR allocator (default for vanilla clusters).
    ipam = {
      mode = "kubernetes"
    }

    # Talos-specific: explicit capability lists are required because the
    # Talos runtime refuses to apply caps that aren't in the pod spec.
    securityContext = {
      capabilities = {
        ciliumAgent = [
          "CHOWN",
          "KILL",
          "NET_ADMIN",
          "NET_RAW",
          "IPC_LOCK",
          "SYS_ADMIN",
          "SYS_RESOURCE",
          "DAC_OVERRIDE",
          "FOWNER",
          "SETGID",
          "SETUID",
        ]
        cleanCiliumState = [
          "NET_ADMIN",
          "SYS_ADMIN",
          "SYS_RESOURCE",
        ]
      }
    }


    # Talos already mounts cgroup v2 at /sys/fs/cgroup; tell Cilium not to
    # try to mount it itself.
    cgroup = {
      autoMount = { enabled = false }
      hostRoot  = "/sys/fs/cgroup"
    }

    # Hubble + UI for observability (replaces Weave Scope topology view).
    hubble = {
      relay = { enabled = true }
      ui    = { enabled = true }
    }

    # LoadBalancer mode (NOT hostNetwork). Talos's BPF/kernel hardening
    # blocks bind to privileged ports even for root+privileged containers
    # in the host namespace, so hostNetwork mode is non-viable on this
    # platform. Hetzner CCM provisions a real LB (~€5/mo) that forwards
    # :443 to a high NodePort that Envoy binds without privilege issues.
    # See [[note: stateful workloads on hetzner talos]] for full context.
    gatewayAPI = {
      enabled      = true
      gatewayClass = { create = "true" }
    }

    # Single-node PoC — one operator replica is enough.
    operator = {
      replicas = 1
    }
  })]

  # Helm provider's default wait covers DaemonSet readiness.
  timeout = 600

  depends_on = [
    kubernetes_secret.hcloud,
    kubectl_manifest.gateway_api_crds,
  ]
}

# Hetzner Cloud Controller Manager — initializes nodes with cloud metadata,
# manages routes for the private network, removes the uninitialized taint.
resource "helm_release" "hcloud_ccm" {
  name       = "hcloud-cloud-controller-manager"
  repository = "https://charts.hetzner.cloud"
  chart      = "hcloud-cloud-controller-manager"
  version    = var.hcloud_ccm_chart_version
  namespace  = "kube-system"

  values = [yamlencode({
    networking = {
      enabled     = true
      clusterCIDR = var.pod_cidr
    }
    # CCM uses hostNetwork; Recreate avoids host-port conflict on rollouts.
    strategy = { type = "Recreate" }
  })]

  timeout = 300

  depends_on = [helm_release.cilium]
}

# Argo CD namespace.
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "managed-by" = "terragrunt"
    }
  }

  depends_on = [helm_release.hcloud_ccm]
}

# Argo CD itself, plus the three AppProjects via extraObjects.
# Inlining AppProjects in the same release avoids the kubernetes_manifest
# plan-time CRD lookup problem.
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [yamlencode({
    # Server config. ClusterIP service is exposed via an HTTPRoute in
    # 30-networking. `--insecure` tells argocd-server to skip its own TLS
    # termination and speak plain HTTP on :80 — the Gateway terminates TLS
    # using the wildcard cert.
    server = {
      service = { type = "ClusterIP" }
      extraArgs = [
        "--insecure",
      ]
    }
  })]

  timeout = 600
}

# AppProjects — Terraform owns the inventory, Argo owns the runtime.
# Using kubectl_manifest (gavinbunney/kubectl) because it doesn't do plan-time
# CRD lookup, so it works even though the AppProject CRD is installed in the
# same apply by the Argo CD Helm chart.
locals {
  appprojects = {
    platform = {
      description = "Core platform components managed by Terraform/Terragrunt."
      destinations = [{
        namespace = "*"
        server    = "https://kubernetes.default.svc"
      }]
      clusterResourceWhitelist = [
        { group = "*", kind = "*" }
      ]
      namespaceResourceWhitelist = [
        { group = "*", kind = "*" }
      ]
    }

    projects = {
      description = "Friend-group / side-project apps. Restricted namespaces and resource kinds."
      destinations = [{
        namespace = "projects-*"
        server    = "https://kubernetes.default.svc"
      }]
      clusterResourceWhitelist = []
      namespaceResourceWhitelist = [
        { group = "", kind = "ConfigMap" },
        { group = "", kind = "Secret" },
        { group = "", kind = "Service" },
        { group = "", kind = "ServiceAccount" },
        { group = "apps", kind = "Deployment" },
        { group = "apps", kind = "StatefulSet" },
        { group = "batch", kind = "Job" },
        { group = "batch", kind = "CronJob" },
        { group = "gateway.networking.k8s.io", kind = "HTTPRoute" },
      ]
    }

    sandbox = {
      description = "Experimental / throwaway. Tightest namespace restrictions."
      destinations = [{
        namespace = "sandbox-*"
        server    = "https://kubernetes.default.svc"
      }]
      clusterResourceWhitelist = []
      namespaceResourceWhitelist = [
        { group = "", kind = "ConfigMap" },
        { group = "", kind = "Service" },
        { group = "apps", kind = "Deployment" },
      ]
    }
  }
}

resource "kubectl_manifest" "appproject" {
  for_each = local.appprojects

  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = each.key
      namespace = kubernetes_namespace.argocd.metadata[0].name
    }
    spec = merge(
      {
        sourceRepos = ["*"]
      },
      each.value,
    )
  })

  depends_on = [helm_release.argocd]
}
