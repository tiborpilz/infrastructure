output "managed_groups" {
  description = "Authentik groups managed by Terraform."
  value       = module.authentik_config.managed_groups
}

output "managed_users" {
  description = "Authentik users managed by Terraform."
  value       = module.authentik_config.managed_users
}

output "managed_user_passwords" {
  description = "Generated and supplied passwords for managed users."
  value       = module.authentik_config.managed_user_passwords
  sensitive   = true
}

output "argocd_application_slug" {
  description = "authentik Application slug for Argo CD."
  value       = module.argocd_oidc.argocd_application_slug
}

output "forgejo_url" {
  description = "Public Forgejo URL."
  value       = module.forgejo.forgejo_url
}

output "forgejo_namespace" {
  description = "Namespace where Forgejo is installed."
  value       = module.forgejo.forgejo_namespace
}

output "woodpecker_url" {
  description = "Public Woodpecker URL."
  value       = module.woodpecker.woodpecker_url
}

output "woodpecker_namespace" {
  description = "Namespace where Woodpecker is installed."
  value       = module.woodpecker.woodpecker_namespace
}

output "pds_url" {
  description = "Public URL of the self-hosted PDS."
  value       = module.pds.pds_url
}

output "pds_admin_password" {
  description = "PDS admin password (basic auth user `admin`). Needed to mint invite codes."
  value       = module.pds.admin_password
  sensitive   = true
}

output "pds_invite_code" {
  description = "Fresh single-use PDS invite code, re-minted on every refresh."
  value       = module.pds.invite_code
  sensitive   = true
}
