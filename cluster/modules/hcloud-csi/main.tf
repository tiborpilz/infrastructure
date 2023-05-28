variable "hcloud_token" {
  type        = string
  description = "The hetzner cloud token to use"
}

variable "hcloud_csi_version" {
  type        = string
  description = "The hcloud csi version to use"
  default     = "master"
}

module "hcloud_csi" {
  source = "../download-manifest"
  urls = [
    "https://raw.githubusercontent.com/hetznercloud/csi-driver/${var.hcloud_csi_version}/deploy/kubernetes/hcloud-csi.yml",
  ]
  output_file = "${path.module}/templates-out/hcloud_csi.yaml"
}

locals {
  hcloud_token_manifest = templatefile("${path.module}/templates/hcloud_token.tpl.yaml", {
    hcloud_token = var.hcloud_token
  })
}

resource "local_file" "hcloud_token" {
  filename = "${path.module}/templates-out/hcloud_token.yaml"
  content  = local.hcloud_token_manifest
}

output "files" {
  value = [
    module.hcloud_csi.file.filename,
    local_file.hcloud_token.filename,
  ]
}

output "manifest" {
  value = join("\n---\n", [
    module.hcloud_csi.manifest,
    local.hcloud_token_manifest,
  ])
}
