output "storage_class" {
  description = "Default StorageClass created by hcloud-csi. CNPG Cluster CRs reference this."
  value       = "hcloud-volumes"
}

output "cnpg_namespace" {
  description = "Namespace where the CloudNativePG operator runs."
  value       = kubernetes_namespace.cnpg_system.metadata[0].name
}

output "hcloud_csi_chart_version" {
  description = "hcloud-csi Helm chart version that was applied."
  value       = var.hcloud_csi_chart_version
}

output "cnpg_chart_version" {
  description = "cloudnative-pg Helm chart version that was applied."
  value       = var.cnpg_chart_version
}

# Sentinel that downstream layers depend on to ensure CSI + CNPG are ready
# before they apply Cluster CRs. Reading this output forces the wait to
# resolve first.
output "ready" {
  description = "True once hcloud-csi StorageClass exists and CNPG operator is Available."
  value       = terraform_data.platform_data_ready.id != null
}
