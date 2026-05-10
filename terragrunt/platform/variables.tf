variable "kubernetes_host" {
  description = "Kubernetes API server URL."
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate."
  type        = string
  sensitive   = true
}

variable "client_certificate" {
  description = "Kubernetes client certificate."
  type        = string
  sensitive   = true
}

variable "client_key" {
  description = "Kubernetes client key."
  type        = string
  sensitive   = true
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig used by readiness waits."
  type        = string
}

variable "talosconfig_raw" {
  description = "Raw talosconfig YAML for the etcd snapshot job."
  type        = string
  sensitive   = true
}

variable "talos_cp_endpoints" {
  description = "Public IPv4 addresses of Talos control-plane endpoints."
  type        = list(string)
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token."
  type        = string
  sensitive   = true
}

variable "hcloud_network_id" {
  description = "Hetzner Cloud private network ID."
  type        = string
}
variable "hcloud_object_storage_region" {
  description = "Hetzner Object Storage region."
  type        = string
}

variable "hcloud_s3_access_key" {
  description = "Hetzner Object Storage S3 access key."
  type        = string
  sensitive   = true
}

variable "hcloud_s3_secret_key" {
  description = "Hetzner Object Storage S3 secret key."
  type        = string
  sensitive   = true
}

variable "bucket_name" {
  description = "Backup bucket name."
  type        = string
}

variable "domain" {
  description = "Public domain."
  type        = string
}

variable "admin_email" {
  description = "Bootstrap admin email."
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token."
  type        = string
  sensitive   = true
}

variable "cert_manager_values" {
  description = "Rendered Helm values for cert-manager."
  type        = string
}

variable "external_dns_values" {
  description = "Rendered Helm values for external-dns."
  type        = string
}

variable "hcloud_csi_values" {
  description = "Rendered Helm values for hcloud-csi."
  type        = string
}

variable "cnpg_values" {
  description = "Rendered Helm values for CloudNativePG."
  type        = string
}

variable "velero_values" {
  description = "Rendered Helm values for Velero."
  type        = string
}

variable "authentik_values_yaml" {
  description = "Rendered base Helm values for authentik."
  type        = string
}

variable "authentik_database_yaml" {
  description = "Rendered CNPG Cluster YAML for authentik."
  type        = string
}

variable "authentik_valkey_service_yaml" {
  description = "Rendered Valkey Service YAML."
  type        = string
}

variable "authentik_valkey_statefulset_yaml" {
  description = "Rendered Valkey StatefulSet YAML."
  type        = string
}
