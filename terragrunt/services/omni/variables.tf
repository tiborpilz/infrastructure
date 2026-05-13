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

variable "kubeconfig_path" {
  description = "Path to a kubeconfig file. Used by the readiness wait's local-exec kubectl call."
  type        = string
}

variable "domain" {
  description = "Public domain. Omni is exposed at <subdomain>.<domain>."
  type        = string
}

variable "subdomain" {
  description = "Subdomain for the Omni UI / main API."
  type        = string
  default     = "omni"
}

variable "k8s_proxy_subdomain" {
  description = "Subdomain for the Kubernetes API proxy that Omni exposes."
  type        = string
  default     = "omni-k8s"
}

variable "siderolink_subdomain" {
  description = "Subdomain for the SideroLink gRPC machine API."
  type        = string
  default     = "omni-siderolink"
}

variable "gateway_namespace" {
  description = "Namespace of the public Gateway. From platform output."
  type        = string
}

variable "gateway_name" {
  description = "Name of the public Gateway. From platform output."
  type        = string
}

variable "storage_class" {
  description = "StorageClass for Omni's PVC. From platform-data output."
  type        = string
  default     = "hcloud-volumes"
}

variable "platform_data_ready" {
  description = "Sentinel from platform-data. Forces this layer to wait until the StorageClass is present."
  type        = bool
}

variable "authentik_url" {
  description = "Public URL of the authentik instance. From platform output."
  type        = string
}

variable "authentik_token" {
  description = "Bootstrap admin token for the authentik API. From platform output."
  type        = string
  sensitive   = true
}

variable "authentik_ready" {
  description = "Sentinel from platform. Forces this layer to wait until authentik is reachable."
  type        = bool
}

variable "authentik_config_ready" {
  description = "Sentinel proving shared authentik users/groups have been applied before Omni is deployed."
  type        = bool
  default     = true
}

variable "omni_chart_revision" {
  description = "Git tag of siderolabs/omni used to pin the Helm chart pulled by ArgoCD from `deploy/helm/omni`."
  type        = string
  default     = "v1.7.2"
}

variable "omni_etcd_gpg_key" {
  description = "GPG private key (ASCII-armored) used by Omni to encrypt its embedded etcd. Generate via `gpg --batch --passphrase '' --quick-gen-key Omni default default never && gpg --armor --export-secret-keys Omni`. Stored in SOPS as `omni_etcd_gpg_key`."
  type        = string
  sensitive   = true
}

variable "omni_admin_emails" {
  description = "Emails of initial Omni admins. Only applied on the FIRST boot of Omni (when its etcd is empty); subsequent changes have no effect — manage admins via the Omni UI or `omnictl` after first install. Each email must be able to authenticate via the Authentik OIDC flow."
  type        = list(string)
}

variable "siderolink_wireguard_endpoint" {
  description = "Public `<ip>:<port>` endpoint that managed Talos nodes use to establish the SideroLink WireGuard tunnel. Hostnames are not supported by the WireGuard config; must be a worker public IP plus the WireGuard NodePort (default 30180)."
  type        = string
}

variable "omni_values_yaml" {
  description = "Rendered Helm values for the Omni chart."
  type        = string
}
