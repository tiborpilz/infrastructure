output "components_namespace" {
  description = "Namespace where Tekton Pipelines/Triggers/Chains/Dashboard run. Use this as the target for oauth2-proxy upstream lookups."
  value       = var.components_namespace
}

output "operator_namespace" {
  description = "Namespace where the Tekton operator itself runs."
  value       = kubernetes_namespace.tekton_operator.metadata[0].name
}

output "dashboard_service_name" {
  description = "ClusterIP Service for the Tekton Dashboard. Stable across Dashboard pod rollouts."
  value       = "tekton-dashboard"
}

output "dashboard_service_port" {
  description = "Port the Tekton Dashboard Service listens on."
  value       = 9097
}

output "ready" {
  description = "Sentinel that downstream layers can depend on once Tekton is fully reconciled."
  value       = terraform_data.tekton_ready.id != null
}
