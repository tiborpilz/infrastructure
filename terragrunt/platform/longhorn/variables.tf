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

variable "argocd_ready" {
  description = "Sentinel proving Argo CD is reachable. Carries the upstream wait's resource ID."
  type        = string
  default     = ""
}

variable "longhorn_chart_version" {
  description = "Longhorn Helm chart version."
  type        = string
  default     = "1.7.2"
}

variable "longhorn_values" {
  description = "Rendered Helm values for Longhorn."
  type        = string
}
