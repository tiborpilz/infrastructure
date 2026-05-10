variable "kubernetes_host" {
  description = "Kubernetes API server URL. From cluster output."
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Cluster CA certificate (PEM). From cluster output."
  type        = string
  sensitive   = true
}

variable "client_certificate" {
  description = "Kubernetes client certificate (PEM). From cluster output."
  type        = string
  sensitive   = true
}

variable "client_key" {
  description = "Kubernetes client key. From cluster output."
  type        = string
  sensitive   = true
}

variable "kubeconfig_path" {
  description = "Path to a kubeconfig file. Used by the readiness wait's local-exec kubectl call."
  type        = string
}

variable "domain" {
  description = "Public domain. Forgejo is exposed at git.<domain>."
  type        = string
}

variable "subdomain" {
  description = "Subdomain for Forgejo."
  type        = string
  default     = "git"
}

variable "gateway_namespace" {
  description = "Namespace of the public Gateway. From platform output."
  type        = string
}

variable "gateway_name" {
  description = "Name of the public Gateway. From platform output."
  type        = string
}

variable "storage_class" {
  description = "StorageClass name for Forgejo data and CNPG PVCs. From platform-data output."
  type        = string
  default     = "hcloud-volumes"
}

variable "platform_data_ready" {
  description = "Sentinel from platform-data. Forces this layer to wait until the StorageClass + CNPG operator are present."
  type        = bool
}

variable "authentik_url" {
  description = "Public URL of the authentik instance. From platform output."
  type        = string
}

variable "authentik_token" {
  description = "Bootstrap admin token for the authentik API. From platform output."
  type        = string
  sensitive   = true
}

variable "authentik_ready" {
  description = "Sentinel from platform. Forces this layer to wait until authentik is reachable."
  type        = bool
}

variable "authentik_config_ready" {
  description = "Sentinel proving shared authentik users/groups have been applied before Forgejo is deployed."
  type        = bool
  default     = true
}

variable "admin_email" {
  description = "Email address for the Terraform-managed Forgejo break-glass admin user."
  type        = string
}

variable "forgejo_chart_version" {
  description = "Forgejo Helm chart version."
  type        = string
  default     = "17.0.1"
}

variable "forgejo_values_yaml" {
  description = "Rendered Helm values for the Forgejo chart."
  type        = string
}

variable "database_yaml" {
  description = "Rendered CNPG Cluster YAML for Forgejo's database."
  type        = string
}
