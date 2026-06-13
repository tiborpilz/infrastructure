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
