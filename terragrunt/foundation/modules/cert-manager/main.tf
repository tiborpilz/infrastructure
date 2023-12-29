variable "email" {
  type = string
}

variable "cert_manager_version" {
  type        = string
  description = "The cert-manager version to use"
  default     = "main"
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
    "https://github.com/cert-manager/cert-manager/releases/download/${var.cert_manager_version}/cert-manager.yaml",
    local_file.letsencrypt_clusterissuer.filename,
  ]
}
