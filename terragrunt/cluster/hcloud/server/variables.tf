variable "env_name" {
  description = "Environment name. Used in resource names and labels."
  type        = string
}

variable "location" {
  description = "Hetzner Cloud location (e.g., fsn1, nbg1, ash)."
  type        = string
  default     = "fsn1"
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

variable "control_plane_nodes" {
  description = "Map of control-plane nodes' short name with their optional private ipv4."
  type = map(object({
    server_type  = string
    private_ipv4 = optional(string)
  }))
}

variable "worker_nodes" {
  description = "Map of worker nodes' short name with their optional private ipv4. Empty map means no worker nodes. Addinga volume size attaches a separate volume."
  type = map(object({
    server_type    = string
    private_ipv4   = optional(string)
    volume_size_gb = optional(number)
  }))
  default = {}
}

variable "subnet_id" {
  description = "Hetzner Cloud subnet ID to attach server private NICs to. Output of the hcloud/network module."
  type        = string
}

variable "firewall_ids" {
  description = "Firewall IDs to apply to servers. Empty list if firewall is disabled."
  type        = list(string)
  default     = []
}
