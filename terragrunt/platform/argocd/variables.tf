variable "kubernetes_host" {
  description = "Kubernetes API server URL. From cluster output."
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Cluster CA certificate (PEM). From cluster output."
  type        = string
  sensitive   = true
}

variable "client_certificate" {
  description = "Kubernetes client certificate (PEM). From cluster output."
  type        = string
  sensitive   = true
}

variable "client_key" {
  description = "Kubernetes client key. From cluster output."
  type        = string
  sensitive   = true
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token. Used by hcloud-cloud-controller-manager."
  type        = string
  sensitive   = true
}

variable "hcloud_network_id" {
  description = "Hetzner Cloud private network ID. From cluster output. CCM uses this for cluster routing."
  type        = string
}

variable "pod_cidr" {
  description = "Pod CIDR. Must match what was set in cluster."
  type        = string
  default     = "10.244.0.0/16"
}

variable "cilium_chart_version" {
  description = "Cilium Helm chart version."
  type        = string
  default     = "1.19.3"
}

variable "hcloud_ccm_chart_version" {
  description = "hcloud-cloud-controller-manager Helm chart version."
  type        = string
  default     = "1.31.0"
}

variable "argocd_chart_version" {
  description = "Argo CD Helm chart version."
  type        = string
  default     = "9.5.13"
}

variable "domain" {
  description = "Public domain. Argo CD UI is exposed at argocd.<domain>."
  type        = string
}

variable "argocd_subdomain" {
  description = "Subdomain for the Argo CD UI."
  type        = string
  default     = "argocd"
}

variable "gateway_api_version" {
  description = "Gateway API version. CRDs are fetched from the kubernetes-sigs/gateway-api release at this tag and applied before Cilium reconciles Gateway resources."
  type        = string
  default     = "v1.2.1"
}

variable "ksops_image" {
  description = "viaductoss/ksops image used as an initContainer to drop ksops + kustomize binaries into the Argo CD repo-server."
  type        = string
  default     = "viaductoss/ksops:v4.3.2"
}

variable "sops_age_key" {
  description = "Cluster age private key (whole keys.txt body). Mounted into Argo CD's repo-server at ~/.config/sops/age/keys.txt so KSOPS can decrypt SOPS-encrypted manifests pulled from Git."
  type        = string
  sensitive   = true
}
