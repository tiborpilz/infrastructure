output "namespace" {
  description = "Namespace where Longhorn runs."
  value       = kubernetes_namespace.longhorn_system.metadata[0].name
}

output "storage_class" {
  description = "Name of the Longhorn StorageClass for opt-in PVCs. Use as `storageClassName: longhorn` on workloads where local-disk-only / cluster-agnostic is acceptable."
  value       = "longhorn"
}

output "ready" {
  description = "Sentinel that downstream layers can depend on once Longhorn manager is rolled out."
  value       = terraform_data.longhorn_ready.id != null
}
