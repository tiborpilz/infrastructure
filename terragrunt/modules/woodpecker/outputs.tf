output "woodpecker_url" {
  description = "Public URL where Woodpecker is reachable."
  value       = local.woodpecker_url
}

output "woodpecker_namespace" {
  description = "Namespace where Woodpecker is installed."
  value       = kubernetes_namespace.woodpecker.metadata[0].name
}

output "forgejo_oauth_app_name" {
  description = "Forgejo OAuth2 application name used by Woodpecker."
  value       = gitea_oauth2_app.woodpecker.name
}

output "forgejo_oauth_redirect_uri" {
  description = "Redirect URI registered on the Forgejo OAuth2 application."
  value       = local.forgejo_oauth_redirect_uri
}

output "woodpecker_chart_version" {
  description = "Woodpecker Helm chart version that was applied."
  value       = var.woodpecker_chart_version
}

output "ready" {
  description = "Sentinel that downstream layers can depend on once Woodpecker is healthy."
  value       = terraform_data.woodpecker_ready.id != null
}
