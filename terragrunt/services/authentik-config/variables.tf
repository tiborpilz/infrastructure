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
  description = "Sentinel from platform. Forces this layer to wait until authentik is reachable before its provider tries to talk to the API."
  type        = bool
}
