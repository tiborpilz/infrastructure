variable "ips" {
  type    = list(string)
  default = []
}

variable "metallb_version" {
  type        = string
  description = "The metallb version to use"
  default     = "main"
}

module "metallb" {
  source = "../download-manifest"
  urls = [
    "https://raw.githubusercontent.com/metallb/metallb/${var.metallb_version}/config/manifests/metallb-native.yaml",
  ]
  output_file = "${path.module}/templates-out/metallb.yaml"
}

locals {
  metallb_address_pool_manifest = templatefile("${path.module}/templates/metallb-address-pool.tpl.yaml", {
    ips = var.ips
  })
}

resource "local_file" "metallb_address_pool" {
  filename = "${path.module}/templates-out/metallb_address_pool.yaml"
  content  = local.metallb_address_pool_manifest
}

output "files" {
  value = [
    module.metallb.filename,
    local_file.metallb_address_pool.filename,
  ]
}

output "manifest" {
  value = join("\n---\n", [
    module.metallb.manifest,
    local.metallb_address_pool_manifest,
  ])
}
