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

variable "argocd_ready" {
  description = "Sentinel proving Argo CD and its Application/AppProject CRDs are served before this module installs Application resources. Carries the upstream wait's resource ID."
  type        = string
  default     = ""
}

variable "metrics_server_chart_version" {
  description = "metrics-server Helm chart version."
  type        = string
  default     = "3.12.2"
}

variable "metrics_server_values" {
  description = "Rendered Helm values for metrics-server."
  type        = string
}
