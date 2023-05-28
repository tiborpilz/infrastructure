variable "urls" {
  type        = list(string)
  description = "The urls of the yaml manifests (use this for multiple manifests)"
  default     = []
}

variable "namespace" {
  type        = string
  description = "optional namespace to add to each resource in the manifest"
  default     = "kube-system"
}

variable "output_file" {
  type        = string
  description = "File to write the manifest to"
  default     = null
}

variable "templates" {
  type = list(object({
    template = string,
    values   = any,
  }))
  description = "Templates to render"
  default     = []
}

data "http" "manifests" {
  for_each = toset(var.urls)
  url      = each.value
}

locals {
  manifests                = [for key, value in data.http.manifests : value]
  decoded_resources        = flatten([for manifest in local.manifests : [for item in compact(split("---", manifest.response_body)) : yamldecode(item)]])
  resources_with_namespace = [for item in local.decoded_resources : merge(item, { metadata = merge({ namespace = var.namespace }, item.metadata) })]

  template_manifests   = [for item in var.templates : templatefile(item.template, item.values)]
  downloaded_manifests = [for item in local.resources_with_namespace : yamlencode(item)]

  encoded_manifest = join("\n---\n", concat(local.template_manifests, local.downloaded_manifests))
}

resource "local_file" "manifest" {
  filename = var.output_file
  content  = local.encoded_manifest
}

output "manifest" {
  value       = local.encoded_manifest
  description = "The addon as list of manifests with namespace, encoded as yaml, separated by ---"
}

output "file" {
  value       = local_file.manifest
  description = "The manifest file"
}
