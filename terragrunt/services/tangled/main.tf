locals {
  enabled = var.owner_handle != "" && var.owner_signing_key_multibase != ""

  namespace    = "tangled"
  hostname     = "${var.subdomain}.${var.domain}"
  knot_url     = "https://${local.hostname}"
  did_hostname = "${var.did_subdomain}.${var.domain}"
  owner_did    = "did:web:${local.did_hostname}"

  did_document = jsonencode({
    "@context" = [
      "https://www.w3.org/ns/did/v1",
      "https://w3id.org/security/multikey/v1",
    ]
    id          = local.owner_did
    alsoKnownAs = ["at://${var.owner_handle}"]
    verificationMethod = [{
      id                 = "${local.owner_did}#atproto"
      type               = "Multikey"
      controller         = local.owner_did
      publicKeyMultibase = var.owner_signing_key_multibase
    }]
    service = [{
      id              = "#atproto_pds"
      type            = "AtprotoPersonalDataServer"
      serviceEndpoint = var.owner_pds_endpoint
    }]
  })

  manifests_yaml = templatefile("${path.module}/templates/manifests.yaml.tpl", {
    namespace            = local.namespace
    hostname             = local.hostname
    did_hostname         = local.did_hostname
    owner_did            = local.owner_did
    storage_class        = var.storage_class
    repo_storage_size    = var.repo_storage_size
    app_storage_size     = var.app_storage_size
    sshkeys_storage_size = var.sshkeys_storage_size
    knot_image           = var.knot_image
    knot_image_tag       = var.knot_image_tag
    appview_endpoint     = var.appview_endpoint
    gateway_name         = var.gateway_name
    gateway_namespace    = var.gateway_namespace
    did_web_image        = var.did_web_image
    did_web_image_tag    = var.did_web_image_tag
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

resource "kubernetes_config_map" "did_web" {
  count = local.enabled ? 1 : 0

  metadata {
    name      = "tangled-did-web"
    namespace = kubernetes_namespace.tangled[0].metadata[0].name
  }

  data = {
    "did.json" = local.did_document
  }
}

resource "kubectl_manifest" "tangled" {
  for_each = local.enabled ? { for idx, doc in local.manifest_docs : idx => doc } : {}

  yaml_body = each.value

  depends_on = [
    kubernetes_namespace.tangled,
    kubernetes_config_map.did_web,
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
