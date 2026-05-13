variable "name" {
  description = "Identifier for this oauth2-proxy instance. Used as: the namespace name (`<name>-auth`), the authentik OIDC `client_id` and application slug, the Argo CD Application name, and the HTTPRoute name. Must be DNS-label-safe."
  type        = string
}

variable "display_name" {
  description = "Human-readable name shown in the authentik application picker. Defaults to the title-cased `name`."
  type        = string
  default     = null
}

variable "subdomain" {
  description = "Subdomain under `var.domain` that this instance fronts. Defaults to `var.name`."
  type        = string
  default     = null
}

variable "upstream_service_namespace" {
  description = "Namespace of the Service that oauth2-proxy will forward authenticated traffic to."
  type        = string
}

variable "upstream_service_name" {
  description = "Name of the upstream Service."
  type        = string
}

variable "upstream_service_port" {
  description = "Port on the upstream Service."
  type        = number
  default     = 80
}

variable "admin_groups" {
  description = "authentik groups whose members may authenticate to this application. Enforced server-side via authentik_policy_binding — users not in any of these groups are rejected at the IdP before oauth2-proxy is involved."
  type        = list(string)
  default     = []
}

variable "oauth2_proxy_chart_version" {
  description = "oauth2-proxy Helm chart version."
  type        = string
  default     = "7.7.31"
}

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

variable "authentik_url" {
  description = "Public URL of the authentik server."
  type        = string
}

variable "authentik_token" {
  description = "Bootstrap API token for the authentik provider."
  type        = string
  sensitive   = true
}

variable "authentik_ready" {
  description = "Sentinel from platform. Forces this layer to wait until authentik is reachable."
  type        = bool
}

variable "authentik_config_ready" {
  description = "Sentinel ensuring authentik's managed groups exist before binding them to this application."
  type        = bool
  default     = true
}

variable "domain" {
  description = "Public domain. Full hostname becomes `<subdomain>.<domain>`."
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

variable "argocd_namespace" {
  description = "Namespace where Argo CD Applications are created."
  type        = string
  default     = "argocd"
}

variable "kubeconfig_path" {
  description = "Path to a kubeconfig file on disk. Used by the wait that blocks HTTPRoute creation until the oauth2-proxy Service exists."
  type        = string
}
