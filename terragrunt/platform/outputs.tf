output "argocd_url" {
  description = "Public URL of the Argo CD UI."
  value       = "https://argocd.${var.domain}"
}

output "argocd_oidc_client_id" {
  description = "OIDC client_id Argo CD uses against Authentik."
  value       = "argocd"
}

output "argocd_oidc_client_secret" {
  description = "OIDC client_secret for Argo CD (from cluster bootstrap random_password)."
  value       = var.argocd_oidc_client_secret
  sensitive   = true
}

output "argocd_oidc_redirect_uri" {
  description = "Redirect URI Authentik must whitelist for Argo CD."
  value       = "https://argocd.${var.domain}/auth/callback"
}

output "authentik_url" {
  description = "Public URL of the Authentik instance."
  value       = "https://auth.${var.domain}"
}

output "authentik_token" {
  description = "Authentik API bootstrap token."
  value       = var.authentik_bootstrap_token
  sensitive   = true
}

output "authentik_ready" {
  description = "Sentinel: Authentik deployment is rolled out."
  value       = local.authentik_ready
}


output "gateway_namespace" {
  description = "Namespace hosting the public Gateway."
  value       = module.networking.gateway_namespace
}

output "gateway_name" {
  description = "Name of the public Gateway."
  value       = module.networking.gateway_name
}

output "storage_class" {
  description = "Default platform StorageClass."
  value       = module.platform_data.storage_class
}

output "platform_data_ready" {
  description = "Sentinel proving platform data controllers are ready."
  value       = module.platform_data.ready
}


