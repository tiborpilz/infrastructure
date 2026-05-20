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
  description = "Sentinel proving Argo CD and its Application/AppProject CRDs are served before this module installs Application resources."
  type        = string
  default     = ""
}

variable "cluster_autoscaler_chart_version" {
  description = "cluster-autoscaler Helm chart version."
  type        = string
  default     = "9.57.0"
}

variable "cluster_autoscaler_values" {
  description = "Rendered Helm values for cluster-autoscaler."
  type        = string
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token. Used by cluster-autoscaler to provision/decommission VMs."
  type        = string
  sensitive   = true
}

variable "worker_machine_config" {
  description = "Talos worker MachineConfig (YAML) handed to autoscaler-provisioned nodes as Hetzner user-data. Sensitive — contains cluster bootstrap material."
  type        = string
  sensitive   = true
}
