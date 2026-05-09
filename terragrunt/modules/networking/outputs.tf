output "domain" {
  description = "Public domain configured for the cluster."
  value       = var.domain
}

output "gateway_namespace" {
  description = "Namespace hosting the public Gateway."
  value       = kubernetes_namespace.gateway_system.metadata[0].name
}

output "gateway_name" {
  description = "Name of the public Gateway. HTTPRoutes attach via parentRefs."
  value       = "public"
}

output "wildcard_tls_secret" {
  description = "Name of the Secret holding the wildcard cert. Populated by cert-manager once the cert is issued."
  value       = "${local.domain_slug}-wildcard-tls"
}

output "cert_manager_chart_version" {
  description = "cert-manager Helm chart version that was applied."
  value       = var.cert_manager_chart_version
}

output "external_dns_chart_version" {
  description = "external-dns Helm chart version that was applied."
  value       = var.external_dns_chart_version
}
