output "bucket_name" {
  description = "S3 bucket holding Velero backups and Talos etcd snapshots."
  value       = minio_s3_bucket.backups.bucket
}

output "velero_namespace" {
  description = "Namespace where Velero runs."
  value       = kubernetes_namespace.velero.metadata[0].name
}

output "velero_chart_version" {
  description = "vmware-tanzu/velero chart version that was applied."
  value       = var.velero_chart_version
}

# Sentinel that downstream layers can depend on once they need to wait for
# backups to be wired up. Reading this output forces the readiness wait to
# resolve first.
output "ready" {
  description = "True once Velero is Healthy and the etcd snapshot CronJob is registered."
  value       = terraform_data.velero_ready.id != null
}
