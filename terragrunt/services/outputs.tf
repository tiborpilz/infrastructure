output "argocd_application_slug" {
  description = "authentik Application slug for Argo CD."
  value       = module.argocd_oidc.argocd_application_slug
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
