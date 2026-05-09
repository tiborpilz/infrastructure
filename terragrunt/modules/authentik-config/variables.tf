variable "authentik_url" {
  description = "Public URL of the authentik instance. From 40-authentik output."
  type        = string
}

variable "authentik_token" {
  description = "Bootstrap admin token for the authentik API. From 40-authentik output."
  type        = string
  sensitive   = true
}

variable "authentik_ready" {
  description = "Sentinel from 40-authentik. Forces this layer to wait until authentik is reachable before its provider tries to talk to the API."
  type        = bool
}

variable "platform_groups" {
  description = "Names of platform-level groups to create. Empty placeholders that downstream RBAC bindings reference (e.g., kube-apiserver OIDC group → ClusterRoleBinding)."
  type        = list(string)
  default = [
    "platform-admins",
    "kubernetes-admins",
  ]
}
