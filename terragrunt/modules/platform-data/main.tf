locals {
  argocd_namespace = "argocd"
}

# ---------------------------------------------------------------------------
# Namespaces. Each Application targets its own namespace; we own the namespace
# so labels/annotations stay TF-managed even if Argo CD recreates objects.
# ---------------------------------------------------------------------------

resource "kubernetes_namespace" "hcloud_csi" {
  metadata {
    name = "hcloud-csi"
    labels = {
      "managed-by" = "terragrunt"

      # Talos enforces Pod Security Standards on workload namespaces. The
      # hcloud-csi-node DaemonSet runs privileged (needed to mount volumes
      # into kubelet's plugin dir), so this namespace must allow privileged
      # pods. kube-system has these labels by default — that's why the CCM
      # works there without extra config.
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

# hcloud-csi looks for a Secret named `hcloud` (key `token`) in its own
# namespace. The CCM's Secret in kube-system isn't reachable cross-namespace,
# so we duplicate the value here. Same token, two consumers.
resource "kubernetes_secret" "hcloud" {
  metadata {
    name      = "hcloud"
    namespace = kubernetes_namespace.hcloud_csi.metadata[0].name
  }

  data = {
    token = var.hcloud_token
  }
}

resource "kubernetes_namespace" "cnpg_system" {
  metadata {
    name = "cnpg-system"
    labels = {
      "managed-by" = "terragrunt"
    }
  }
}

# ---------------------------------------------------------------------------
# hcloud-csi — Argo CD Application.
# The hcloud-csi chart looks for the `hcloud` Secret in kube-system (key
# `token`). That Secret already exists from 20-argocd (created for the CCM),
# so no additional secret wiring needed here.
# ---------------------------------------------------------------------------

resource "kubectl_manifest" "argo_app_hcloud_csi" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "hcloud-csi"
      namespace = local.argocd_namespace
    }
    spec = {
      project = "platform"
      source = {
        repoURL        = "https://charts.hetzner.cloud"
        chart          = "hcloud-csi"
        targetRevision = var.hcloud_csi_chart_version
        helm = {
          values = var.hcloud_csi_values
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.hcloud_csi.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "ServerSideApply=true",
          "CreateNamespace=false",
        ]
      }
    }
  })
}

# ---------------------------------------------------------------------------
# CloudNativePG operator — Argo CD Application.
# The chart bundles its own CRDs. ServerSideApply handles the >256KB CRDs
# that exceed the kubectl client-side annotation size limit.
# ---------------------------------------------------------------------------

resource "kubectl_manifest" "argo_app_cnpg" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "cnpg-operator"
      namespace = local.argocd_namespace
    }
    spec = {
      project = "platform"
      source = {
        repoURL        = "https://cloudnative-pg.github.io/charts"
        chart          = "cloudnative-pg"
        targetRevision = var.cnpg_chart_version
        helm = {
          values = var.cnpg_values
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.cnpg_system.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "ServerSideApply=true",
          "CreateNamespace=false",
        ]
      }
    }
  })
}

# ---------------------------------------------------------------------------
# Readiness gate. Downstream layers (40-authentik) need both the StorageClass
# and the CNPG controller before they can apply Cluster CRs. Same pattern as
# 30-networking's cert-manager wait.
#
# Re-running terragrunt apply is idempotent: terraform_data only re-executes
# if its `triggers_replace` value changes.
# ---------------------------------------------------------------------------

resource "terraform_data" "platform_data_ready" {
  triggers_replace = [
    kubectl_manifest.argo_app_hcloud_csi.uid,
    kubectl_manifest.argo_app_cnpg.uid,
  ]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    # Argo CD Healthy implies all resources in the chart are healthy
    # (Deployments at full replica count, etc.) — no need to wait on the
    # operator Deployment by name (which depends on the release name and is
    # brittle).
    command = <<-EOT
      set -euo pipefail
      kubectl wait --for=jsonpath='{.status.health.status}=Healthy' \
        application/hcloud-csi -n ${local.argocd_namespace} --timeout=10m
      kubectl wait --for=jsonpath='{.status.health.status}=Healthy' \
        application/cnpg-operator -n ${local.argocd_namespace} --timeout=10m
      kubectl get storageclass hcloud-volumes >/dev/null
    EOT
  }
}
