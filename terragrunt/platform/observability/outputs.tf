output "namespace" {
  description = "Namespace where kube-prometheus-stack runs."
  value       = kubernetes_namespace.observability.metadata[0].name
}

output "grafana_url" {
  description = "Public URL of Grafana."
  value       = local.grafana_url
}

output "ready" {
  description = "Sentinel that downstream layers can depend on once Grafana + Prometheus are healthy."
  value       = terraform_data.observability_ready.id != null
}
