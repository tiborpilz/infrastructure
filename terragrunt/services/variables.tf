variable "kubernetes_host" {
  description = "Kubernetes API server URL."
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate."
  type        = string
  sensitive   = true
}

variable "client_certificate" {
  description = "Kubernetes client certificate."
  type        = string
  sensitive   = true
}

variable "client_key" {
  description = "Kubernetes client key."
  type        = string
  sensitive   = true
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig used by readiness waits."
  type        = string
}

variable "domain" {
  description = "Public domain."
  type        = string
}

variable "admin_email" {
  description = "Platform admin email."
  type        = string
}

variable "gateway_namespace" {
  description = "Namespace of the public Gateway."
  type        = string
}

variable "gateway_name" {
  description = "Name of the public Gateway."
  type        = string
}

variable "storage_class" {
  description = "Default platform StorageClass."
  type        = string
}

variable "platform_data_ready" {
  description = "Sentinel proving platform data controllers are ready."
  type        = bool
}

variable "authentik_url" {
  description = "Public URL of the authentik instance."
  type        = string
}

variable "authentik_token" {
  description = "Bootstrap admin token for the authentik API."
  type        = string
  sensitive   = true
}

variable "authentik_ready" {
  description = "Sentinel proving authentik is reachable."
  type        = bool
}

variable "argocd_url" {
  description = "Public URL of the Argo CD UI."
  type        = string
}

variable "argocd_oidc_client_id" {
  description = "OIDC client_id baked into Argo CD."
  type        = string
}

variable "argocd_oidc_client_secret" {
  description = "OIDC client_secret baked into Argo CD."
  type        = string
  sensitive   = true
}

variable "argocd_oidc_redirect_uri" {
  description = "Redirect URI authentik must whitelist for Argo CD."
  type        = string
}

variable "woodpecker_values_yaml" {
  description = "Rendered Helm values for Woodpecker."
  type        = string
}

variable "woodpecker_admins" {
  description = "Forgejo usernames that should become Woodpecker admins."
  type        = list(string)
  default     = []
}

variable "omni_values_yaml" {
  description = "Rendered Helm values for Omni."
  type        = string
  default     = ""
}

variable "omni_etcd_gpg_key" {
  description = "GPG private key (ASCII-armored) used by Omni to encrypt its embedded etcd. Empty string keeps the Omni module dormant; supply via SOPS once you've run the gpg --quick-gen-key bootstrap (see services/omni/README.md)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "omni_admin_emails" {
  description = "Emails of initial Omni admins. Only applied on the first Omni boot — manage further admins via the Omni UI / omnictl thereafter."
  type        = list(string)
  default     = []
}

variable "omni_siderolink_wireguard_endpoint" {
  description = "Public `<ip>:<port>` endpoint that managed Talos nodes use to establish SideroLink WireGuard tunnels. Typically a worker public IP + the WireGuard NodePort (default 30180)."
  type        = string
  default     = ""
}

variable "pds_handles" {
  description = "Handle labels routed to the self-hosted PDS, e.g. [\"tibor\"] for the handle tibor.<domain>."
  type        = list(string)
  default     = []
}

variable "tangled_knot_image" {
  description = "Container image for the tangled knot."
  type        = string
  default     = "ghcr.io/dvjn/tangled-knot"
}

variable "tangled_knot_image_tag" {
  description = "Tag for the tangled knot container image."
  type        = string
  default     = "v1.14.0-alpha"
}

variable "tangled_did_subdomain" {
  description = "Subdomain where the owner's did:web document is served. Owner DID becomes did:web:<tangled_did_subdomain>.<domain>."
  type        = string
  default     = "id"
}

variable "tangled_owner_handle" {
  description = "AT Protocol handle of the knot owner. Empty keeps the module dormant."
  type        = string
  default     = ""
}

variable "tangled_owner_signing_key_multibase" {
  description = "Owner's atproto signing public key in multibase format. Empty keeps the module dormant."
  type        = string
  default     = ""
}

variable "tangled_owner_pds_endpoint" {
  description = "AT Protocol PDS endpoint hosting the owner's account."
  type        = string
  default     = "https://bsky.social"
}
