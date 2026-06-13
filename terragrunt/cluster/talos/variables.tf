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

variable "hcloud_token" {
  description = "Hetzner Cloud API token passed to bootstrap (hcloud-ccm + hcloud-csi secrets)."
  type        = string
  sensitive   = true
}

variable "network_name" {
  description = "Hetzner Cloud private network name. Added to the hcloud secret so CCM can route through it."
  type        = string
}

variable "domain" {
  description = "Apex domain. Used for Gateway hostnames and cert-manager ClusterIssuer."
  type        = string
}

variable "location" {
  description = "Hetzner Cloud location. Used for the LB location annotation on the Gateway."
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for cert-manager DNS-01 and external-dns."
  type        = string
  sensitive   = true
}

variable "admin_email" {
  description = "Admin email for Let's Encrypt and Authentik."
  type        = string
}

variable "floating_ip_address" {
  description = "Public IPv4 of the ingress floating IP. Applied post-cluster as a CiliumLoadBalancerIPPool."
  type        = string
}

variable "bootstrap_manifests_path" {
  description = "Filesystem path to write all bootstrap inline manifests as YAML. If null, no file is written."
  type        = string
  default     = null
}

variable "authentik_secret_key" {
  description = "Authentik secret key (AUTHENTIK_SECRET_KEY). Stable across rebuilds — rotating it invalidates all sessions."
  type        = string
  sensitive   = true
}

variable "argocd_age_key" {
  description = "Age private key for SOPS decryption by ArgoCD (in bootstrap manifests)."
  type        = string
  sensitive   = true
}
