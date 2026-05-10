output "authentik_namespace" {
  description = "Namespace where authentik is installed."
  value       = kubernetes_namespace.authentik.metadata[0].name
}

output "authentik_url" {
  description = "Public URL where authentik is reachable."
  value       = "https://${var.subdomain}.${var.domain}"
}

output "bootstrap_admin_token" {
  description = "Initial akadmin API token. Consumed by services to configure authentik via the goauthentik/authentik provider."
  value       = random_password.bootstrap_admin_token.result
  sensitive   = true
}

output "bootstrap_admin_password" {
  description = "Initial akadmin password. Replaced by a stable TF-pinned password in services; this output exists only so the operator can log in before that layer applies."
  value       = random_password.bootstrap_admin_password.result
  sensitive   = true
}

output "ready" {
  description = "Sentinel that services depends on to ensure authentik is reachable before talking to its API."
  value       = terraform_data.authentik_ready.id != null
}

output "authentik_chart_version" {
  description = "authentik Helm chart version that was applied."
  value       = var.authentik_chart_version
}
