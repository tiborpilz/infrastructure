output "forgejo_url" {
  description = "Public URL where Forgejo is reachable."
  value       = local.forgejo_url
}

output "forgejo_namespace" {
  description = "Namespace where Forgejo is installed."
  value       = kubernetes_namespace.forgejo.metadata[0].name
}

output "forgejo_oidc_application_slug" {
  description = "authentik Application slug for Forgejo."
  value       = authentik_application.forgejo.slug
}

output "forgejo_chart_version" {
  description = "Forgejo Helm chart version that was applied."
  value       = var.forgejo_chart_version
}

output "ready" {
  description = "Sentinel that downstream layers can depend on once Forgejo is healthy."
  value       = terraform_data.forgejo_ready.id != null
}
