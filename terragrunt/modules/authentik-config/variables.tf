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
  description = "Names of platform-level groups to create. Downstream RBAC bindings can reference these by name."
  type        = list(string)
  default = [
    "platform-admins",
    "kubernetes-admins",
  ]
}

variable "platform_admin_groups" {
  description = "Groups assigned to managed users with admin = true."
  type        = list(string)
  default = [
    "platform-admins",
    "kubernetes-admins",
  ]
}

variable "authentik_superuser_groups" {
  description = "Managed groups whose members should be authentik superusers."
  type        = list(string)
  default     = []
}

variable "bootstrap_users" {
  description = "Deprecated alias for managed_users."
  type = map(object({
    name       = string
    email      = string
    admin      = optional(bool, false)
    groups     = optional(list(string), [])
    is_active  = optional(bool, true)
    path       = optional(string, "users/managed")
    attributes = optional(map(string), {})
  }))
  default = {}
}

variable "bootstrap_user_passwords" {
  description = "Deprecated alias for managed_user_passwords."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "managed_users" {
  description = "Declarative Authentik users keyed by username. Passwords come from managed_user_passwords when set, otherwise random_password generates stable values."
  type = map(object({
    name       = string
    email      = string
    admin      = optional(bool, false)
    groups     = optional(list(string), [])
    is_active  = optional(bool, true)
    path       = optional(string, "users/managed")
    attributes = optional(map(string), {})
  }))
  default = {}
}

variable "managed_user_passwords" {
  description = "Optional plaintext passwords for managed users, keyed by username. Intended to be fed from SOPS or another Terragrunt secret source."
  type        = map(string)
  default     = {}
  sensitive   = true
}
