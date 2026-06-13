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
  description = "Public domain hosted at Cloudflare. Gateway uses *.<domain> as wildcard hostname."
  type        = string
}

variable "hcloud_location" {
  description = "Hetzner Cloud location (e.g. fsn1) for the Gateway's LoadBalancer."
  type        = string
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig. Used by the local-exec poll waiting for the Gateway's LoadBalancer external IP."
  type        = string
}
