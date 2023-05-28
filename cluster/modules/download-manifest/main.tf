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
  description = "optional file to write the manifest to"
  default     = null
}

variable "templates" {
  type        = map(string)
  description = "optional templates to render"
  default     = {}
}

variable "template_vars" {
  type        = map(string)
  description = "optional variables to pass to the templates"
  default     = {}
}

data "http" "manifests" {
  for_each = toset(var.urls)
  url      = each.value
}

locals {
  manifests                = [for key, value in data.http.manifests : value]
  decoded_resources        = flatten([for manifest in local.manifests : [for item in compact(split("---", manifest.response_body)) : yamldecode(item)]])
  resources_with_namespace = [for item in local.decoded_resources : merge(item, { metadata = merge({ namespace = var.namespace }, item.metadata) })]

  template_manifests = [for key, value in var.templates : templatefile(value, var.template_vars[key])]
  encoded_manifest   = join("\n---\n", concat([for item in local.resources_with_namespace : yamlencode(item)], local.template_manifests))
}

resource "local_file" "manifest" {
  filename = var.output_file
  content  = local.encoded_manifest
}

output "manifest" {
  value       = local.encoded_manifest
  description = "The manifest with namespace, encoded as yaml"
}

output "file" {
  value       = local_file.manifest
  description = "The manifest file"
}

output "filename" {
  value       = local_file.manifest.filename
  description = "The manifest filename"
}
