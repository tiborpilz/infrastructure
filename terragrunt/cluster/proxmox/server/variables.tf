variable "proxmox_node" {
  description = "Proxmox node (host) name that runs the VMs."
  type        = string
}

variable "image_datastore" {
  description = "Datastore for the downloaded Talos ISO (content type: iso)."
  type        = string
  default     = "first"
}

variable "vm_datastore" {
  description = "Datastore for VM disks and the cloud-init drive."
  type        = string
  default     = "first"
}

variable "snippets_datastore" {
  description = "Datastore with the Snippets content type enabled. Holds the per-node Talos user-data uploaded over SSH."
  type        = string
  default     = "first"
}

variable "network_bridge" {
  description = "Proxmox bridge the VMs attach to."
  type        = string
  default     = "vmbr0"
}

variable "network_gateway" {
  description = "Default gateway for the VM subnet (cloud-init ip_config)."
  type        = string
}

variable "network_cidr" {
  description = "Prefix length for the VM subnet, e.g. 24."
  type        = number
  default     = 24
}

variable "nameservers" {
  description = "DNS servers for the VMs (cloud-init)."
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "talos_version" {
  description = "Talos version (without leading v). Must match the cluster."
  type        = string
}

variable "talos_schematic_id" {
  description = "Talos Image Factory schematic ID for the nocloud ISO. Must include the qemu-guest-agent extension."
  type        = string
}

variable "kubeconfig_path" {
  description = "Path to the cluster kubeconfig. Used by the untaint step once the nodes register."
  type        = string
}

variable "workers" {
  description = "Proxmox worker VMs keyed by node name (the name also becomes the Talos/Kubernetes node name)."
  type = map(object({
    vm_id          = number
    ip             = string
    cores          = optional(number, 4)
    memory         = optional(number, 16384)
    disk_size      = optional(number, 60)
    data_disk_size = optional(number, 100)
  }))
}

variable "worker_machine_configs" {
  description = "Per-node Talos worker MachineConfig keyed by node name, injected as nocloud user-data so the node self-joins. Sensitive — contains cluster bootstrap material."
  type        = map(string)
  sensitive   = true
}
