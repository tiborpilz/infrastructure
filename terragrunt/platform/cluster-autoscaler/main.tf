locals {
  argocd_namespace = "argocd"
  namespace        = "cluster-autoscaler"
  secret_name      = "cluster-autoscaler-hcloud"
}

resource "terraform_data" "argocd_gate" {
  input = var.argocd_ready
}

resource "kubernetes_namespace" "cluster_autoscaler" {
  metadata {
    name = local.namespace
    labels = {
      "managed-by" = "terragrunt"
    }
  }
}

# Secret consumed by the cluster-autoscaler pod. HCLOUD_CLOUD_INIT must be
# base64-encoded — the Hetzner cloud provider decodes it before submitting to
# the Hetzner API, and the Hetzner API in turn delivers the decoded blob as
# user-data, which Talos's Hetzner platform reader picks up as MachineConfig.
resource "kubernetes_secret" "hcloud" {
  metadata {
    name      = local.secret_name
    namespace = kubernetes_namespace.cluster_autoscaler.metadata[0].name
  }

  data = {
    HCLOUD_TOKEN      = var.hcloud_token
    HCLOUD_CLOUD_INIT = base64encode(var.worker_machine_config)
  }
}

resource "kubectl_manifest" "argo_app_cluster_autoscaler" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "cluster-autoscaler"
      namespace = local.argocd_namespace
    }
    spec = {
      project = "platform"
      source = {
        repoURL        = "https://kubernetes.github.io/autoscaler"
        chart          = "cluster-autoscaler"
        targetRevision = var.cluster_autoscaler_chart_version
        helm = {
          values = var.cluster_autoscaler_values
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.cluster_autoscaler.metadata[0].name
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

  depends_on = [
    terraform_data.argocd_gate,
    kubernetes_namespace.cluster_autoscaler,
    kubernetes_secret.hcloud,
  ]
}

resource "terraform_data" "cluster_autoscaler_ready" {
  triggers_replace = [kubectl_manifest.argo_app_cluster_autoscaler.uid]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      set -euo pipefail
      kubectl wait --for=jsonpath='{.status.sync.status}'=Synced \
        application/cluster-autoscaler -n ${local.argocd_namespace} --timeout=5m
      kubectl wait --for=jsonpath='{.status.health.status}'=Healthy \
        application/cluster-autoscaler -n ${local.argocd_namespace} --timeout=5m
    EOT
  }
}
