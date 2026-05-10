variable "env_name" {
  description = "Environment name. Used in resource names and labels."
  type        = string
}

variable "cluster_name" {
  description = "Kubernetes/Talos cluster name."
  type        = string
}

variable "location" {
  description = "Hetzner Cloud location."
  type        = string
}

variable "network_cidr" {
  description = "CIDR for the private network."
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR for the cluster subnet."
  type        = string
}

variable "talos_image_labels" {
  description = "Labels selecting the Talos snapshot to boot."
  type        = map(string)
}

variable "firewall_admin_ips" {
  description = "CIDRs allowed to reach Talos and Kubernetes APIs."
  type        = list(string)
  default     = []
}

variable "control_plane_nodes" {
  description = "Control-plane nodes keyed by short name."
  type = map(object({
    server_type  = string
    private_ipv4 = optional(string)
  }))
}

variable "worker_nodes" {
  description = "Worker nodes keyed by short name."
  type = map(object({
    server_type  = string
    private_ipv4 = optional(string)
  }))
  default = {}
}

variable "talos_version" {
  description = "Talos version."
  type        = string
}

variable "kubeconfig_path" {
  description = "Path where the kubeconfig should be written."
  type        = string
}

variable "talosconfig_path" {
  description = "Path where the talosconfig should be written."
  type        = string
}
