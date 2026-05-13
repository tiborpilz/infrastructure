variable "kubernetes_host" {
  type = string
}

variable "cluster_ca_certificate" {
  type      = string
  sensitive = true
}

variable "client_certificate" {
  type      = string
  sensitive = true
}

variable "client_key" {
  type      = string
  sensitive = true
}

variable "domain" {
  description = "Public domain. The smoke app is exposed at <subdomain>.<domain>."
  type        = string
}

variable "subdomain" {
  description = "Subdomain prefix for the smoke app."
  type        = string
  default     = "smoke"
}

variable "gateway_namespace" {
  description = "Namespace of the public Gateway to attach to."
  type        = string
  default     = "gateway-system"
}

variable "gateway_name" {
  description = "Name of the public Gateway to attach to."
  type        = string
  default     = "public"
}

variable "image" {
  description = "Container image for the smoke app."
  type        = string
  default     = "nginx:1.27-alpine"
}
