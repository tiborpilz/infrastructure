variable "authentik_url" {
  description = "Public URL of the authentik instance. From platform output."
  type        = string
}

variable "authentik_token" {
  description = "Bootstrap admin token for the authentik API. From platform output."
  type        = string
  sensitive   = true
}

variable "authentik_ready" {
  description = "Sentinel from platform. Forces this layer to wait until authentik is reachable."
  type        = bool
}

variable "argocd_url" {
  description = "Public URL of the Argo CD UI. From platform output."
  type        = string
}

variable "argocd_oidc_client_id" {
  description = "OIDC client_id baked into Argo CD's Helm values."
  type        = string
}

variable "argocd_oidc_client_secret" {
  description = "OIDC client_secret baked into Argo CD's Helm values. Must match exactly here so the OIDC handshake succeeds."
  type        = string
  sensitive   = true
}

variable "argocd_oidc_redirect_uri" {
  description = "Redirect URI authentik must whitelist for Argo CD's OIDC callback."
  type        = string
}
