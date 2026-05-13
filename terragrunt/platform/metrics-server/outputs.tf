output "ready" {
  description = "Sentinel that downstream layers can depend on once metrics-server is healthy and the metrics APIService is available."
  value       = terraform_data.metrics_server_ready.id != null
}
