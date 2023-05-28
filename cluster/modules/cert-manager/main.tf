variable "email" {
  type = string
}

variable "cert_manager_version" {
  type        = string
  description = "The cert-manager version to use"
  default     = "main"
}

module "cert_manager" {
  source = "../download-manifest"
  urls = [
    "https://github.com/cert-manager/cert-manager/releases/download/v1.9.1/cert-manager.yaml",
  ]
  output_file = "${path.module}/templates-out/cert-manager.yaml"
}

locals {
  letsencrypt_clusterissuer_manifest = templatefile("${path.module}/templates/letsencrypt-clusterissuer.tpl.yaml", {
    email = var.email
  })
}

resource "local_file" "letsencrypt_clusterissuer" {
  filename = "${path.module}/templates-out/letsencrypt-clusterissuer.yaml"
  content  = local.letsencrypt_clusterissuer_manifest
}

output "files" {
  value = [
    module.cert_manager.filename,
    local_file.letsencrypt_clusterissuer.filename,
  ]
}

output "manifest" {
  value = join("\n---\n", [
    module.cert_manager.manifest,
    local.letsencrypt_clusterissuer_manifest,
  ])
}
