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
  description = "Path to a kubeconfig file. Used by readiness waits."
  type        = string
}

variable "domain" {
  description = "Public domain. Woodpecker is exposed at ci.<domain>."
  type        = string
}

variable "subdomain" {
  description = "Subdomain for Woodpecker."
  type        = string
  default     = "ci"
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
  description = "StorageClass name for Woodpecker PVCs and pipeline workspace PVCs."
  type        = string
  default     = "hcloud-volumes"
}

variable "platform_data_ready" {
  description = "Sentinel from platform-data. Forces this layer to wait until the StorageClass is present."
  type        = bool
}

variable "forgejo_url" {
  description = "Public Forgejo URL. From services output."
  type        = string
}

variable "forgejo_namespace" {
  description = "Namespace where Forgejo is installed. From services output."
  type        = string
}

variable "woodpecker_chart_version" {
  description = "Woodpecker Helm chart version."
  type        = string
  default     = "3.2.0"
}

variable "woodpecker_admins" {
  description = "Forgejo usernames that should become Woodpecker admins."
  type        = list(string)
  default     = []
}

variable "woodpecker_server_data_size" {
  description = "Persistent volume size for Woodpecker server data."
  type        = string
  default     = "10Gi"
}

variable "woodpecker_agent_data_size" {
  description = "Persistent volume size for Woodpecker agent state."
  type        = string
  default     = "1Gi"
}

variable "woodpecker_pipeline_volume_size" {
  description = "Default PVC size for Kubernetes-backed Woodpecker pipeline workspaces."
  type        = string
  default     = "10G"
}

variable "woodpecker_values_yaml" {
  description = "Rendered Helm values for the Woodpecker chart."
  type        = string
}
