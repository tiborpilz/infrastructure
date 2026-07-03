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
  description = "Worker nodes keyed by short name. volume_size_gb (optional) attaches a raw hcloud_volume of that size for storage workloads like Ceph."
  type = map(object({
    server_type    = string
    private_ipv4   = optional(string)
    volume_size_gb = optional(number)
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

variable "domain" {
  description = "Apex domain for cluster DNS records. Must match an existing Cloudflare zone."
  type        = string
}

variable "gitops_repo_url" {
  description = "Git repository URL the ArgoCD root Application (app-of-apps) syncs from."
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:Edit on the configured zone. Consumed by the cloudflare provider via CLOUDFLARE_API_TOKEN."
  type        = string
  sensitive   = true
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token. Consumed by the hcloud provider via HCLOUD_TOKEN."
  type        = string
  sensitive   = true
}

variable "admin_email" {
  description = "Admin email for Let's Encrypt and Authentik."
  type        = string
}

variable "bootstrap_manifests_path" {
  description = "Filesystem path to write all bootstrap inline manifests as YAML. If null, no file is written."
  type        = string
  default     = null
}

variable "authentik_secret_key" {
  description = "Authentik secret key. Stable across rebuilds."
  type        = string
  sensitive   = true
}

variable "argocd_age_key" {
  description = "Age private key for SOPS decryption by ArgoCD."
  type        = string
  sensitive   = true
}

variable "proxmox_workers" {
  description = "Proxmox-hosted worker VMs keyed by node name (the name becomes the Kubernetes node name)."
  type = map(object({
    vm_id          = number
    ip             = string
    cores          = optional(number, 4)
    memory         = optional(number, 16384)
    disk_size      = optional(number, 60)
    data_disk_size = optional(number, 100)
    install_disk   = optional(string, "/dev/vda")
  }))
  default = {}
}

variable "proxmox_insecure" {
  description = "Skip TLS verification against the Proxmox API (self-signed certs)."
  type        = bool
  default     = true
}

variable "proxmox_ssh_username" {
  description = "SSH user bpg uses to upload Talos user-data snippets to the Proxmox host."
  type        = string
  default     = "root"
}

variable "proxmox_ssh_private_key" {
  description = "Private key contents for the Proxmox SSH user. Consumed by the proxmox provider for snippet upload."
  type        = string
  sensitive   = true
  default     = ""
}

variable "proxmox_ssh_password" {
  description = "Password for the Proxmox SSH user. Consumed by the proxmox provider for snippet upload. bpg falls back to this when no usable key is offered."
  type        = string
  sensitive   = true
  default     = ""
}

variable "proxmox_node" {
  description = "Proxmox node (host) name that runs the worker VMs."
  type        = string
  default     = "proxmox"
}

variable "proxmox_image_datastore" {
  description = "Datastore for the Talos ISO."
  type        = string
  default     = "local"
}

variable "proxmox_vm_datastore" {
  description = "Datastore for VM disks and cloud-init."
  type        = string
  default     = "local-lvm"
}

variable "proxmox_snippets_datastore" {
  description = "Datastore with Snippets content enabled, for per-node Talos user-data."
  type        = string
  default     = "local"
}

variable "proxmox_network_bridge" {
  description = "Proxmox bridge the worker VMs attach to."
  type        = string
  default     = "vmbr0"
}

variable "proxmox_network_gateway" {
  description = "Default gateway for the Proxmox worker subnet."
  type        = string
  default     = "10.0.10.1"
}

variable "proxmox_network_cidr" {
  description = "Prefix length for the Proxmox worker subnet."
  type        = number
  default     = 24
}

variable "proxmox_nameservers" {
  description = "DNS servers for the Proxmox worker VMs."
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "proxmox_talos_schematic_id" {
  description = "Talos Image Factory schematic ID for the Proxmox nocloud ISO. Must include qemu-guest-agent."
  type        = string
  default     = ""
}
