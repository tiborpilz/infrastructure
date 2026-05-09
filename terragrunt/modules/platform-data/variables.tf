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

variable "hcloud_token" {
  description = "Hetzner Cloud API token. The hcloud-csi chart looks for a Secret named `hcloud` (key `token`) in its own namespace; this module creates that Secret. Same value as the kube-system/hcloud Secret used by the CCM."
  type        = string
  sensitive   = true
}

variable "hcloud_csi_chart_version" {
  description = "hcloud-csi Helm chart version."
  type        = string
  default     = "2.18.0"
}

variable "cnpg_chart_version" {
  description = "cloudnative-pg Helm chart version (operator + CRDs)."
  type        = string
  default     = "0.27.0"
}

variable "hcloud_csi_values" {
  description = "Rendered Helm values for hcloud-csi."
  type        = string
}

variable "cnpg_values" {
  description = "Rendered Helm values for cloudnative-pg operator."
  type        = string
}
