locals {
  argocd_namespace   = "argocd"
  operator_namespace = "tekton-operator"

  # Pre-rendered install manifest from the GitHub release. The raw
  # `config/base` kustomize sources use `ko://` placeholders that don't
  # resolve outside the operator's release pipeline — this URL is the
  # `ko resolve`'d artifact and is the upstream-recommended install path.
  release_manifest_url = "https://github.com/tektoncd/operator/releases/download/${var.operator_revision}/release.yaml"
}

resource "terraform_data" "platform_data_gate" {
  input = var.platform_data_ready
}

# The operator runs in its own namespace; the components it manages
# (Pipelines/Triggers/Chains/Dashboard) land in `var.components_namespace`,
# which the operator creates itself when reconciling the TektonConfig CR.
resource "kubernetes_namespace" "tekton_operator" {
  metadata {
    name = local.operator_namespace
    labels = {
      "managed-by" = "terragrunt"
    }
  }
}

data "http" "operator_release" {
  url = local.release_manifest_url
  # release.yaml is ~3 MB. The default 10s timeout covers DNS + TCP dial +
  # TLS handshake + redirect walk + download. Bumping to 60s gives the dial
  # itself room to complete even on a slow first connection to GitHub.
  request_timeout_ms = 60000
}

# Split the multi-doc YAML into one entry per resource. `manifests` is keyed
# by `<group>/<kind>/<namespace>/<name>` so for_each is stable across applies.
data "kubectl_file_documents" "operator_release" {
  content = data.http.operator_release.response_body
}

# Apply each document individually. server_side_apply lets us co-own fields
# with the operator (it patches its own ConfigMaps at runtime); without SSA
# we'd get apply storms when the operator mutates its own state.
#
# force_conflicts steals field ownership from any other manager that already
# has them. Needed on first apply after we transition from ArgoCD ownership
# (the previous broken sync) to TF ownership, and harmless on subsequent runs.
resource "kubectl_manifest" "operator_release" {
  for_each = data.kubectl_file_documents.operator_release.manifests

  yaml_body         = each.value
  server_side_apply = true
  force_conflicts   = true

  depends_on = [
    terraform_data.platform_data_gate,
    kubernetes_namespace.tekton_operator,
  ]
}

# The TektonConfig CRD comes in via the release manifest above. Even with
# server-side apply, the CRD-established and Deployment-ready states are
# async — wait for both before applying the TektonConfig CR.
resource "terraform_data" "wait_for_operator" {
  triggers_replace = {
    manifest_count = length(data.kubectl_file_documents.operator_release.manifests)
  }

  depends_on = [kubectl_manifest.operator_release]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    # kubectl wait errors immediately on NotFound — it doesn't poll for the
    # resource to appear. ArgoCD's sync is async after the Application is
    # created, so the CRD might not exist for a minute. Poll until it does,
    # *then* wait for `established`, then for the operator Deployment.
    command = <<-EOT
      set -euo pipefail
      for i in $(seq 1 60); do
        if kubectl get crd tektonconfigs.operator.tekton.dev >/dev/null 2>&1; then
          echo "tektonconfigs CRD present"
          break
        fi
        echo "waiting for tektonconfigs CRD (attempt $i/60)..."
        sleep 5
      done
      kubectl wait --for=condition=established \
        crd/tektonconfigs.operator.tekton.dev --timeout=2m
      for i in $(seq 1 60); do
        if kubectl -n ${local.operator_namespace} \
             get deployment tekton-operator >/dev/null 2>&1; then
          break
        fi
        echo "waiting for tekton-operator deployment to appear (attempt $i/60)..."
        sleep 5
      done
      kubectl -n ${local.operator_namespace} \
        rollout status deployment/tekton-operator --timeout=5m
    EOT
  }
}

# Profile `all` installs Pipelines + Triggers + Chains + Dashboard (also
# Results/Hub which are harmless when unused). The pruner keeps run history
# bounded so long-running clusters don't accumulate dead PipelineRun objects.
resource "kubectl_manifest" "tekton_config" {
  yaml_body = yamlencode({
    apiVersion = "operator.tekton.dev/v1alpha1"
    kind       = "TektonConfig"
    metadata = {
      name = "config"
    }
    spec = {
      profile         = "all"
      targetNamespace = var.components_namespace
      pruner = {
        resources = ["pipelinerun", "taskrun"]
        keep      = var.pruner_keep
        schedule  = var.pruner_schedule
      }
    }
  })

  depends_on = [terraform_data.wait_for_operator]
}

resource "terraform_data" "tekton_ready" {
  triggers_replace = {
    config_uid = kubectl_manifest.tekton_config.uid
  }

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      set -euo pipefail
      # TektonConfig reports an aggregated Ready condition once all enabled
      # components have reconciled successfully.
      kubectl wait --for=condition=Ready \
        tektonconfig/config --timeout=15m
      kubectl -n ${var.components_namespace} \
        rollout status deployment/tekton-dashboard --timeout=10m
    EOT
  }
}
