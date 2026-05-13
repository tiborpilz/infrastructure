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
  description = "Public domain. Grafana is exposed at <subdomain>.<domain>."
  type        = string
}

variable "subdomain" {
  description = "Subdomain for Grafana."
  type        = string
  default     = "grafana"
}

variable "argocd_ready" {
  description = "Sentinel proving Argo CD and its Application/AppProject CRDs are served before this module installs Application resources. Carries the upstream wait's resource ID."
  type        = string
  default     = ""
}

variable "platform_data_ready" {
  description = "Sentinel from platform-data. Grafana and Prometheus need the StorageClass to be present before they create PVCs."
  type        = bool
}

variable "authentik_url" {
  description = "Public URL of the authentik instance."
  type        = string
}

variable "authentik_token" {
  description = "Bootstrap admin token for the authentik API."
  type        = string
  sensitive   = true
}

variable "authentik_ready" {
  description = "Sentinel proving authentik is reachable."
  type        = bool
}

variable "storage_class" {
  description = "StorageClass for Prometheus, Alertmanager, and Grafana PVCs."
  type        = string
}

variable "gateway_namespace" {
  description = "Namespace of the public Gateway."
  type        = string
}

variable "gateway_name" {
  description = "Name of the public Gateway."
  type        = string
}

variable "kube_prometheus_stack_chart_version" {
  description = "kube-prometheus-stack Helm chart version."
  type        = string
  default     = "67.10.0"
}

variable "kube_prometheus_stack_values" {
  description = "Rendered Helm values for kube-prometheus-stack."
  type        = string
}

variable "admin_groups" {
  description = "Authentik groups that grant Grafana Admin role. Users in none of these groups get rejected at OIDC login (role_attribute_path returns empty)."
  type        = list(string)
  default     = ["platform-admins"]
}
