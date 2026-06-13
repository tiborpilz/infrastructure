locals {
  namespace = "pds"
  hostname  = "${var.subdomain}.${var.domain}"
  pds_url   = "https://${local.hostname}"

  # Handles are first-level labels under the apex: tibor.<domain>. The PDS
  # answers /.well-known/atproto-did for any account whose handle matches the
  # request Host, so each handle just needs an HTTPRoute pointing at it.
  handle_hostnames = [for h in var.handles : "${h}.${var.domain}"]

  manifests_yaml = templatefile("${path.module}/templates/manifests.yaml.tpl", {
    namespace         = local.namespace
    hostname          = local.hostname
    handle_hostnames  = local.handle_hostnames
    handle_domains    = ".${var.domain}"
    crawlers          = var.crawlers
    storage_class     = var.storage_class
    data_storage_size = var.data_storage_size
    pds_image         = var.pds_image
    pds_image_tag     = var.pds_image_tag
    gateway_name      = var.gateway_name
    gateway_namespace = var.gateway_namespace
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
  input = var.platform_data_ready
}

# ---------------------------------------------------------------------------
# Secrets. Generated once into TF state, mirroring what upstream's
# installer.sh would have written to pds.env.
# ---------------------------------------------------------------------------

resource "random_bytes" "jwt_secret" {
  length = 16
}

resource "random_bytes" "admin_password" {
  length = 16
}

# K-256 (secp256k1) private key as raw 32-byte scalar. Any random 32-byte
# value below the curve order is a valid key; the chance of drawing one at
# or above it is ~2^-128, so plain random bytes are fine here.
resource "random_bytes" "plc_rotation_key" {
  length = 32
}

resource "kubernetes_namespace" "pds" {
  metadata {
    name = local.namespace
    labels = {
      "managed-by" = "terragrunt"
    }
  }
}

resource "kubernetes_secret" "pds_env" {
  metadata {
    name      = "pds-env"
    namespace = kubernetes_namespace.pds.metadata[0].name
  }

  data = {
    PDS_JWT_SECRET                            = random_bytes.jwt_secret.hex
    PDS_ADMIN_PASSWORD                        = random_bytes.admin_password.hex
    PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX = random_bytes.plc_rotation_key.hex
  }
}

resource "kubectl_manifest" "pds" {
  for_each = { for idx, doc in local.manifest_docs : idx => doc }

  yaml_body = each.value

  depends_on = [
    kubernetes_namespace.pds,
    kubernetes_secret.pds_env,
    terraform_data.platform_data_gate,
  ]
}

# Mints a single-use invite code. Data sources re-read on refresh, so every
# plan against a reachable PDS produces a fresh code; codes are free and
# single-use, so the churn is harmless. Requires network access to the PDS —
# plans from machines that can't reach it will fail here.
data "http" "invite_code" {
  url    = "${local.pds_url}/xrpc/com.atproto.server.createInviteCode"
  method = "POST"

  request_headers = {
    Authorization = "Basic ${base64encode("admin:${random_bytes.admin_password.hex}")}"
    Content-Type  = "application/json"
  }

  request_body = jsonencode({ useCount = 1 })

  retry {
    attempts     = 3
    min_delay_ms = 2000
  }

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "createInviteCode failed with HTTP status ${self.status_code}."
    }
  }

  depends_on = [terraform_data.pds_ready]
}

resource "terraform_data" "pds_ready" {
  triggers_replace = [
    for k in sort(keys(kubectl_manifest.pds)) : kubectl_manifest.pds[k].uid
  ]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      set -euo pipefail
      kubectl -n ${local.namespace} \
        wait --for=condition=Available deployment/pds --timeout=10m
      kubectl -n ${local.namespace} \
        wait --for=jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'=True \
        httproute/pds --timeout=5m
    EOT
  }
}
