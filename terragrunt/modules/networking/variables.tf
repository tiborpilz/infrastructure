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

variable "domain" {
  description = "Public domain hosted at Cloudflare. external-dns creates records under this zone; the Gateway uses *.<domain> as its wildcard hostname."
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
