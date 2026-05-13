locals {
  argocd_namespace = "argocd"
}

resource "terraform_data" "argocd_gate" {
  input = var.argocd_ready
}

# metrics-server upstream installs into kube-system, but the chart lets us
# pick a namespace. Keeping it out of kube-system makes the install easier
# to lifecycle without bumping into other kube-system workloads.
resource "kubernetes_namespace" "metrics_server" {
  metadata {
    name = "metrics-server"
    labels = {
      "managed-by" = "terragrunt"
    }
  }
}

resource "kubectl_manifest" "argo_app_metrics_server" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "metrics-server"
      namespace = local.argocd_namespace
    }
    spec = {
      project = "platform"
      source = {
        repoURL        = "https://kubernetes-sigs.github.io/metrics-server"
        chart          = "metrics-server"
        targetRevision = var.metrics_server_chart_version
        helm = {
          values = var.metrics_server_values
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.metrics_server.metadata[0].name
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
    kubernetes_namespace.metrics_server,
  ]
}

resource "terraform_data" "metrics_server_ready" {
  triggers_replace = [kubectl_manifest.argo_app_metrics_server.uid]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      set -euo pipefail
      kubectl wait --for=jsonpath='{.status.sync.status}'=Synced \
        application/metrics-server -n ${local.argocd_namespace} --timeout=5m
      kubectl wait --for=jsonpath='{.status.health.status}'=Healthy \
        application/metrics-server -n ${local.argocd_namespace} --timeout=5m
      # APIService availability is what makes `kubectl top` work; without
      # this, you can apply the chart and still get "Metrics API not available".
      kubectl wait --for=condition=Available \
        apiservice/v1beta1.metrics.k8s.io --timeout=3m
    EOT
  }
}
