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
  description = "Public domain. The PDS is exposed at <subdomain>.<domain>; handles live directly under <domain>."
  type        = string
}

variable "subdomain" {
  description = "Subdomain for the PDS service endpoint."
  type        = string
  default     = "pds"
}

variable "handles" {
  description = "Handle labels to route to the PDS, e.g. [\"tibor\"] serves the handle tibor.<domain>. Each needs an HTTPRoute so the PDS can answer /.well-known/atproto-did for it. Empty list deploys the PDS without handle routes."
  type        = list(string)
  default     = []
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
  description = "StorageClass for the PDS data PVC (sqlite + blobs)."
  type        = string
  default     = "hcloud-volumes"
}

variable "platform_data_ready" {
  description = "Sentinel from platform-data. Forces this layer to wait until the StorageClass is present."
  type        = bool
}

variable "pds_image" {
  description = "Container image for the PDS."
  type        = string
  default     = "ghcr.io/bluesky-social/pds"
}

variable "pds_image_tag" {
  description = "Tag for the PDS container image. Upstream publishes a rolling 0.4 tag."
  type        = string
  default     = "0.4"
}

variable "data_storage_size" {
  description = "PVC size for /pds (sqlite db + blobstore). hcloud-volumes is online-resizable."
  type        = string
  default     = "20Gi"
}

variable "crawlers" {
  description = "Relays the PDS requests crawls from (PDS_CRAWLERS). bsky.network is the main relay; without it the wider network (including the tangled appview) never sees this PDS."
  type        = string
  default     = "https://bsky.network"
}
