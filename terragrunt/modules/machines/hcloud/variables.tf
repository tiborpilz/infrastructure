variable "env_name" {
  description = "Environment name. Used in resource names and labels."
  type        = string
}

variable "location" {
  description = "Hetzner Cloud location (e.g., fsn1, nbg1, hel1, ash, hil, sin)."
  type        = string
  default     = "fsn1"
}

variable "network_cidr" {
  description = "CIDR for the private network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR for the cluster subnet (must be within network_cidr)."
  type        = string
  default     = "10.0.0.0/24"
}

variable "talos_image_labels" {
  description = <<-EOT
    Labels selecting the Talos snapshot to boot. Must match labels set by
    hack/upload-talos-image.sh. Required keys: os, version, arch.
  EOT
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["os", "version", "arch"] : contains(keys(var.talos_image_labels), k)])
    error_message = "talos_image_labels must include keys: os, version, arch."
  }
}

variable "firewall_admin_ips" {
  description = <<-EOT
    CIDRs allowed to reach Talos API (50000) and k8s API (6443).
    Empty list = no firewall is created and both APIs are reachable from
    the public internet. Talos and k8s API are mTLS-protected, so this is
    safe-but-noisy; tighten with a VPN/bastion when one's available.
  EOT
  type        = list(string)
  default     = []
}

variable "control_plane_nodes" {
  description = <<-EOT
    Map of control-plane nodes keyed by short name (e.g., "cp-1").
    private_ipv4 is optional; Hetzner auto-allocates from the subnet if omitted.
  EOT
  type = map(object({
    server_type  = string
    private_ipv4 = optional(string)
  }))
}

variable "worker_nodes" {
  description = <<-EOT
    Map of worker nodes keyed by short name (e.g., "worker-1"). Same shape
    as control_plane_nodes. Empty map = no workers.
  EOT
  type = map(object({
    server_type  = string
    private_ipv4 = optional(string)
  }))
  default = {}
}
