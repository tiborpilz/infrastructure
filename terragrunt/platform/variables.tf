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

variable "hcloud_token" {
  description = "Hetzner Cloud API token."
  type        = string
  sensitive   = true
}

variable "hcloud_location" {
  description = "Hetzner Cloud location (e.g. fsn1)."
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

variable "hcloud_csi_values" {
  description = "Rendered Helm values for hcloud-csi."
  type        = string
}

variable "cnpg_values" {
  description = "Rendered Helm values for CloudNativePG."
  type        = string
}

variable "metrics_server_values" {
  description = "Rendered Helm values for metrics-server."
  type        = string
}

variable "worker_machine_config" {
  description = "Talos worker MachineConfig (YAML) injected as user-data on autoscaler-provisioned nodes."
  type        = string
  sensitive   = true
}

variable "cluster_autoscaler_values" {
  description = "Rendered Helm values for cluster-autoscaler."
  type        = string
}

variable "argocd_oidc_client_secret" {
  description = "ArgoCD OIDC client secret generated in the cluster bootstrap layer."
  type        = string
  sensitive   = true
}

variable "authentik_bootstrap_token" {
  description = "Authentik API bootstrap token generated in the cluster bootstrap layer."
  type        = string
  sensitive   = true
}
