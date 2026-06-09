variable "kubernetes_host" {
  description = "Kubernetes API server URL."
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Cluster CA certificate (PEM)."
  type        = string
  sensitive   = true
}

variable "client_certificate" {
  description = "Kubernetes client certificate (PEM)."
  type        = string
  sensitive   = true
}

variable "client_key" {
  description = "Kubernetes client key."
  type        = string
  sensitive   = true
}

variable "kubeconfig_path" {
  description = "Path to a kubeconfig file. Used by the readiness wait's local-exec kubectl call."
  type        = string
}

variable "domain" {
  description = "Public domain. The knot is exposed at <subdomain>.<domain>."
  type        = string
}

variable "subdomain" {
  description = "Subdomain for the tangled knot."
  type        = string
  default     = "knot"
}

variable "gateway_namespace" {
  description = "Namespace of the public Gateway."
  type        = string
}

variable "gateway_name" {
  description = "Name of the public Gateway."
  type        = string
}

variable "storage_class" {
  description = "StorageClass for the knot's PVCs (sqlite, repos, sshd host keys)."
  type        = string
  default     = "hcloud-volumes"
}

variable "platform_data_ready" {
  description = "Sentinel from platform-data. Forces this layer to wait until the StorageClass is present."
  type        = bool
}

variable "owner_did" {
  description = "AT Protocol DID of the knot owner. Empty string keeps the module dormant. Provide via SOPS once you have a tangled.org account."
  type        = string
  default     = ""
  sensitive   = true
}

variable "appview_endpoint" {
  description = "Tangled appview that this knot federates with."
  type        = string
  default     = "https://tangled.org"
}

variable "knot_image" {
  description = "Container image for the knot. No official image exists; defaults to the community nightly build."
  type        = string
  default     = "ghcr.io/dvjn/tangled-knot"
}

variable "knot_image_tag" {
  description = "Tag for the knot container image. Pin to a tagged release; bump as upstream advances."
  type        = string
  default     = "v1.14.0-alpha"
}

variable "repo_storage_size" {
  description = "PVC size for /home/git/repositories. hcloud-volumes is online-resizable."
  type        = string
  default     = "50Gi"
}

variable "app_storage_size" {
  description = "PVC size for /app (sqlite db + state)."
  type        = string
  default     = "5Gi"
}

variable "sshkeys_storage_size" {
  description = "PVC size for /etc/ssh/keys (sshd host keys)."
  type        = string
  default     = "1Gi"
}
