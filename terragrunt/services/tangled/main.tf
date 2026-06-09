locals {
  # Boolean only — owner_did itself is sensitive, but its presence isn't,
  # so we have to strip the propagated sensitivity for use in count/for_each
  # and module outputs. Mirrors the services/omni pattern.
  enabled = nonsensitive(var.owner_did != "")

  namespace = "tangled"
  hostname  = "${var.subdomain}.${var.domain}"
  knot_url  = "https://${local.hostname}"

  manifests_yaml = templatefile("${path.module}/templates/manifests.yaml.tpl", {
    namespace            = local.namespace
    hostname             = local.hostname
    storage_class        = var.storage_class
    repo_storage_size    = var.repo_storage_size
    app_storage_size     = var.app_storage_size
    sshkeys_storage_size = var.sshkeys_storage_size
    knot_image           = var.knot_image
    knot_image_tag       = var.knot_image_tag
    appview_endpoint     = var.appview_endpoint
    gateway_name         = var.gateway_name
    gateway_namespace    = var.gateway_namespace
  })

  # Template uses `---` separators between YAML docs (including a leading one).
  # Strip any leading `---` and split on the inter-doc separator.
  manifest_docs = [
    for doc in split("\n---", trimprefix(trimspace(local.manifests_yaml), "---")) :
    trimspace(doc)
    if trimspace(doc) != ""
  ]
}

resource "terraform_data" "platform_data_gate" {
  count = local.enabled ? 1 : 0
  input = var.platform_data_ready
}

resource "kubernetes_namespace" "tangled" {
  count = local.enabled ? 1 : 0

  metadata {
    name = local.namespace
    labels = {
      "managed-by" = "terragrunt"
    }
  }
}

resource "kubernetes_secret" "owner" {
  count = local.enabled ? 1 : 0

  metadata {
    name      = "tangled-owner"
    namespace = kubernetes_namespace.tangled[0].metadata[0].name
  }

  data = {
    did = var.owner_did
  }
}

resource "kubectl_manifest" "tangled" {
  for_each = local.enabled ? { for idx, doc in local.manifest_docs : idx => doc } : {}

  yaml_body = each.value

  depends_on = [
    kubernetes_namespace.tangled,
    kubernetes_secret.owner,
    terraform_data.platform_data_gate,
  ]
}

resource "terraform_data" "tangled_ready" {
  count = local.enabled ? 1 : 0

  triggers_replace = [
    for k in sort(keys(kubectl_manifest.tangled)) : kubectl_manifest.tangled[k].uid
  ]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      set -euo pipefail
      kubectl -n ${local.namespace} \
        wait --for=condition=Available deployment/tangled --timeout=10m
      kubectl -n ${local.namespace} \
        wait --for=jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'=True \
        httproute/tangled --timeout=5m
    EOT
  }
}
