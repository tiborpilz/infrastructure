output "argocd_url" {
  description = "Public URL of the Argo CD UI."
  value       = module.argocd.argocd_url
}

output "argocd_oidc_client_id" {
  description = "OIDC client_id Argo CD uses against authentik."
  value       = module.argocd.argocd_oidc_client_id
}

output "argocd_oidc_client_secret" {
  description = "OIDC client_secret baked into Argo CD."
  value       = module.argocd.argocd_oidc_client_secret
  sensitive   = true
}

output "argocd_oidc_redirect_uri" {
  description = "Redirect URI authentik must whitelist for Argo CD."
  value       = module.argocd.argocd_oidc_redirect_uri
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

output "authentik_url" {
  description = "Public URL of the authentik instance."
  value       = module.authentik.authentik_url
}

output "authentik_token" {
  description = "Initial akadmin API token."
  value       = module.authentik.bootstrap_admin_token
  sensitive   = true
}

output "authentik_ready" {
  description = "Sentinel proving authentik is reachable."
  value       = module.authentik.ready
}

output "bootstrap_admin_password" {
  description = "Initial akadmin password."
  value       = module.authentik.bootstrap_admin_password
  sensitive   = true
}

output "smoke_app_url" {
  description = "Smoke app URL."
  value       = module.smoke_app.url
}

output "backup_bucket_name" {
  description = "Velero and etcd snapshot bucket."
  value       = module.velero.bucket_name
}
