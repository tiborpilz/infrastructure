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

variable "hcloud_token" {
  description = "Hetzner Cloud API token. Used by hcloud-cloud-controller-manager."
  type        = string
  sensitive   = true
}

variable "hcloud_network_id" {
  description = "Hetzner Cloud private network ID. From 00-machines output. CCM uses this for cluster routing."
  type        = string
}

variable "pod_cidr" {
  description = "Pod CIDR. Must match what was set in 10-cluster."
  type        = string
  default     = "10.244.0.0/16"
}

variable "cilium_chart_version" {
  description = "Cilium Helm chart version."
  type        = string
  default     = "1.19.3"
}

variable "hcloud_ccm_chart_version" {
  description = "hcloud-cloud-controller-manager Helm chart version."
  type        = string
  default     = "1.31.0"
}

variable "argocd_chart_version" {
  description = "Argo CD Helm chart version."
  type        = string
  default     = "9.5.13"
}

variable "gateway_api_version" {
  description = "Gateway API version. CRDs are fetched from the kubernetes-sigs/gateway-api release at this tag and applied before Cilium reconciles Gateway resources."
  type        = string
  default     = "v1.2.1"
}
