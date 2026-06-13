variable "env_name" {
  description = "Environment name. Used in resource names and labels."
  type        = string
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

variable "network_zone" {
  description = "Hetzner Cloud network zone for the subnet."
  type        = string
  default     = "eu-central"
}

variable "location" {
  description = "Hetzner Cloud location for the floating IP home location."
  type        = string
}

variable "firewall_admin_ips" {
  description = <<-EOT
    CIDRs allowed to reach Talos API (50000) and k8s API (6443).
    An empty list means that no firewall is created and both APIs are reachable from
    the public internet.
  EOT
  type        = list(string)
  default     = []
}
