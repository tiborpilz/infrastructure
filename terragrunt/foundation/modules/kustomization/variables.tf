variable "kustomize_dir" {
  type        = string
  description = "The kustomization's base directory"
}

variable "overlay" {
  type        = any
  description = "An object describing an overlay to apply to the kustomization"
}
