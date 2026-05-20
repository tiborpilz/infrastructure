output "ready" {
  description = "Sentinel resource ID emitted once the cluster-autoscaler Application is Synced + Healthy."
  value       = terraform_data.cluster_autoscaler_ready.id
}
