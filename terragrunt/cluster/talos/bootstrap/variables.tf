variable "cilium_chart_version" {
  description = "Initial Cilium chart version."
  type        = string
  default     = "1.19.3"
}

variable "kubernetes_version" {
  description = "Kubernetes version to pass to `helm template`"
  type        = string
  default     = "1.30.0"
}

variable "argocd_chart_version" {
  description = "Initial argo-cd Helm chart version (chart 7.x == app 2.13.x)."
  type        = string
  default     = "7.8.9"
}

variable "hcloud_ccm_version" {
  description = "Initial hcloud-cloud-controller-manager chart version."
  type        = string
  default     = "1.32.0"
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token for hcloud-csi and hcloud-ccm."
  type        = string
  sensitive   = true
}

variable "network_name" {
  description = "Hetzner Cloud private network name. Added to the hcloud secret so CCM can use private networking."
  type        = string
}

variable "domain" {
  description = "Apex domain for Gateway hostnames and cert-manager ClusterIssuer."
  type        = string
}

variable "location" {
  description = "Hetzner Cloud location for the LB location annotation."
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for cert-manager DNS-01 and external-dns."
  type        = string
  sensitive   = true
}

variable "cert_manager_chart_version" {
  description = "cert-manager Helm chart version."
  type        = string
  default     = "v1.20.2"
}

variable "external_dns_chart_version" {
  description = "external-dns Helm chart version."
  type        = string
  default     = "1.21.1"
}

variable "hcloud_csi_chart_version" {
  description = "Initial hcloud-csi chart version."
  type        = string
  default     = "2.21.2"
}

variable "admin_email" {
  description = "Admin email for Let's Encrypt account registration."
  type        = string
  default     = "tbrpilz@googlemail.com"
}

variable "gateway_api_version" {
  description = "Gateway API CRD release version (experimental install, includes TCPRoute)."
  type        = string
  default     = "v1.2.1"
}

variable "argocd_age_key" {
  description = "Age private key for SOPS decryption by ArgoCD."
  type        = string
  sensitive   = true
}
