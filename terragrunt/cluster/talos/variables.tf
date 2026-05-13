variable "cluster_name" {
  description = "Cluster name. Used in Talos config and certificates."
  type        = string
}

variable "cluster_endpoint" {
  description = <<-EOT
    Cluster API endpoint URL. If null, defaults to
    https://<first-control-plane-public-ipv4>:6443. For HA, set to a load
    balancer URL.
  EOT
  type        = string
  default     = null
}

variable "nodes" {
  description = "Generic node inventory output from the machines layer (cluster)."
  type = object({
    control_plane = map(object({
      name         = string
      ipv4         = string
      public_ipv4  = string
      install_disk = string
      arch         = string
      provider_id  = string
    }))
    workers = map(object({
      name         = string
      ipv4         = string
      public_ipv4  = string
      install_disk = string
      arch         = string
      provider_id  = string
    }))
  })

  validation {
    condition     = length(var.nodes.control_plane) > 0
    error_message = "At least one control-plane node is required."
  }
}

variable "talos_version" {
  description = "Talos version (without leading v), e.g., 1.13.0."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version (without leading v). If null, Talos picks a default for the given Talos version."
  type        = string
  default     = null
}

variable "pod_cidr" {
  description = "Pod network CIDR. Default fits Cilium's recommended layout."
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "Service network CIDR."
  type        = string
  default     = "10.96.0.0/12"
}

variable "dns_domain" {
  description = "Cluster DNS domain."
  type        = string
  default     = "cluster.local"
}

variable "allow_scheduling_on_control_planes" {
  description = <<-EOT
    Allow workloads to schedule on control-plane nodes. Default true for
    single-node clusters where there's nowhere else to put pods. Flip to
    false when dedicated worker nodes exist.
  EOT
  type        = bool
  default     = true
}

variable "kubeconfig_path" {
  description = "Filesystem path to write the kubeconfig to. If null, no file is written (you can still pull it via `terragrunt output -raw kubeconfig`)."
  type        = string
  default     = null
}

variable "talosconfig_path" {
  description = "Filesystem path to write the talosconfig to. If null, no file is written."
  type        = string
  default     = null
}
