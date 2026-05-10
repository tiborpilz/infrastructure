output "argocd_application_slug" {
  description = "authentik Application slug for Argo CD. The OIDC issuer URL Argo CD uses derives from this slug as <authentik_url>/application/o/<slug>/."
  value       = authentik_application.argocd.slug
}

output "argocd_provider_id" {
  description = "authentik provider ID. Useful for downstream resources that bind groups to this provider."
  value       = authentik_provider_oauth2.argocd.id
}
