locals {
  argocd_namespace   = "argocd"
  longhorn_namespace = "longhorn-system"
}

resource "terraform_data" "argocd_gate" {
  input = var.argocd_ready
}

# Longhorn's manager DaemonSet runs privileged (it hostPath-mounts the
# node's filesystem to manage volume replicas), needs hostNetwork in places,
# and uses iscsiadm — all of which violate the baseline PSA. The whole
# `longhorn-system` namespace runs at `privileged`. Scope is tight; no other
# workloads live here.
resource "kubernetes_namespace" "longhorn_system" {
  metadata {
    name = local.longhorn_namespace
    labels = {
      "managed-by" = "terragrunt"

      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

resource "kubectl_manifest" "argo_app_longhorn" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "longhorn"
      namespace = local.argocd_namespace
    }
    spec = {
      project = "platform"
      source = {
        repoURL        = "https://charts.longhorn.io"
        chart          = "longhorn"
        targetRevision = var.longhorn_chart_version
        helm = {
          values = var.longhorn_values
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.longhorn_system.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "ServerSideApply=true",
          "CreateNamespace=false",
          "RespectIgnoreDifferences=true",
        ]
      }
      # Longhorn CRDs ship with the deprecated `preserveUnknownFields: false`
      # on apiextensions.k8s.io/v1; the apiserver normalises it away, so Argo
      # otherwise reports permanent OutOfSync on every CRD.
      ignoreDifferences = [
        {
          group = "apiextensions.k8s.io"
          kind  = "CustomResourceDefinition"
          jsonPointers = [
            "/spec/preserveUnknownFields",
          ]
        },
      ]
    }
  })

  depends_on = [
    terraform_data.argocd_gate,
    kubernetes_namespace.longhorn_system,
  ]
}

resource "terraform_data" "longhorn_ready" {
  triggers_replace = [kubectl_manifest.argo_app_longhorn.uid]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    # The Argo Healthy condition flips green when all Longhorn components
    # land. The DaemonSet (longhorn-manager) won't go Ready unless the host
    # has iscsiadm — if this wait times out, that's the most likely cause.
    # See README for the Talos extension prereq.
    command = <<-EOT
      set -euo pipefail
      kubectl wait --for=jsonpath='{.status.sync.status}'=Synced \
        application/longhorn -n ${local.argocd_namespace} --timeout=10m
      kubectl wait --for=jsonpath='{.status.health.status}'=Healthy \
        application/longhorn -n ${local.argocd_namespace} --timeout=10m
      kubectl -n ${kubernetes_namespace.longhorn_system.metadata[0].name} \
        rollout status daemonset/longhorn-manager --timeout=5m
    EOT
  }
}
