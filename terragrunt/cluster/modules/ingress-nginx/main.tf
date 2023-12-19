variable "ingress_nginx_version" {
  type        = string
  description = "The ingress-nginx version to use"
}

variable "hsts" {
  type        = bool
  description = "Whether to enable HSTS"
  default     = true
}

locals {
  ingress_nginx_manifest = templatefile("${path.module}/templates/ingress-nginx.tpl.yaml", {
    hsts = var.hsts
  })
}

resource "local_file" "ingress_nginx" {
  filename = "${path.module}/templates-out/ingress-nginx.yaml"
  content  = local.ingress_nginx_manifest
}

output "files" {
  value = [
    "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${var.ingress_nginx_version}/deploy/static/provider/cloud/deploy.yaml",
    local_file.ingress_nginx.filename,
  ]
}
