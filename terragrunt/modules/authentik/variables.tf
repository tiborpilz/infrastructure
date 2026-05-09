variable "kubernetes_host" {
  description = "Kubernetes API server URL. From 10-cluster output."
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Cluster CA certificate (PEM). From 10-cluster output."
  type        = string
  sensitive   = true
}

variable "client_certificate" {
  description = "Kubernetes client certificate (PEM). From 10-cluster output."
  type        = string
  sensitive   = true
}

variable "client_key" {
  description = "Kubernetes client key. From 10-cluster output."
  type        = string
  sensitive   = true
}

variable "kubeconfig_path" {
  description = "Path to a kubeconfig file. Used by the readiness wait's local-exec kubectl call."
  type        = string
}

variable "domain" {
  description = "Public domain. authentik is exposed at auth.<domain>."
  type        = string
}

variable "subdomain" {
  description = "Subdomain for authentik. Defaults to `auth`."
  type        = string
  default     = "auth"
}

variable "gateway_namespace" {
  description = "Namespace of the public Gateway. From 30-networking output."
  type        = string
}

variable "gateway_name" {
  description = "Name of the public Gateway. From 30-networking output."
  type        = string
}

variable "platform_data_ready" {
  description = "Sentinel from 35-platform-data. Forces this layer to wait until the StorageClass + CNPG operator are present before applying the Cluster CR."
  type        = bool
}

variable "admin_email" {
  description = "Email address for the bootstrap akadmin user."
  type        = string
}

variable "authentik_chart_version" {
  description = "authentik Helm chart version."
  type        = string
  default     = "2026.2.2"
}

variable "valkey_image" {
  description = "Image for the inlined Valkey StatefulSet."
  type        = string
  default     = "valkey/valkey:8"
}

variable "pg_storage_size" {
  description = "PVC size for the authentik CNPG Cluster."
  type        = string
  default     = "10Gi"
}

variable "storage_class" {
  description = "StorageClass name for the CNPG Cluster's PVC. From 35-platform-data output."
  type        = string
  default     = "hcloud-volumes"
}

variable "authentik_values_yaml" {
  description = "Rendered base Helm values for the authentik chart (no additionalObjects). The module decodes, appends additionalObjects (CNPG Cluster + Valkey Service/StatefulSet), and re-encodes."
  type        = string
}

variable "database_yaml" {
  description = "Rendered CNPG Cluster YAML for authentik's database."
  type        = string
}

variable "valkey_service_yaml" {
  description = "Rendered Valkey Service YAML."
  type        = string
}

variable "valkey_statefulset_yaml" {
  description = "Rendered Valkey StatefulSet YAML."
  type        = string
}
