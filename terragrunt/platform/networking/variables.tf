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

variable "domain" {
  description = "Public domain hosted at Cloudflare. external-dns creates records under this zone; the Gateway uses *.<domain> as its wildcard hostname."
  type        = string
}

variable "hcloud_location" {
  description = "Hetzner Cloud location (e.g. fsn1) for the Gateway's LoadBalancer. Hetzner CCM refuses to create the LB without this."
  type        = string
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig. Used by the local-exec poll that waits for the Gateway's LoadBalancer Service to receive its external IP."
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token. Scoped to the zone with Zone:Read + Zone:DNS:Edit. Used by both cert-manager (DNS-01 challenge) and external-dns."
  type        = string
  sensitive   = true
}

variable "cert_manager_chart_version" {
  description = "cert-manager Helm chart version."
  type        = string
  default     = "v1.20.2"
}

variable "external_dns_chart_version" {
  description = "external-dns Helm chart version."
  type        = string
  default     = "1.21.1"
}

variable "cert_manager_values" {
  description = "Rendered Helm values for the cert-manager Application."
  type        = string
}

variable "external_dns_values" {
  description = "Rendered Helm values for the external-dns Application."
  type        = string
}

variable "argocd_ready" {
  description = "Sentinel proving Argo CD and its Application CRD exist before this module applies Application resources."
  type        = bool
  default     = true
}
