variable "kubernetes_host" {
  description = "Kubernetes API server URL. From 10-cluster output."
  type        = string
}

variable "cluster_ca_certificate" {
  description = "Cluster CA certificate (PEM). From 10-cluster output."
  type        = string
  sensitive   = true
}

variable "client_certificate" {
  description = "Kubernetes client certificate (PEM). From 10-cluster output."
  type        = string
  sensitive   = true
}

variable "client_key" {
  description = "Kubernetes client key. From 10-cluster output."
  type        = string
  sensitive   = true
}

variable "kubeconfig_path" {
  description = "Path to a kubeconfig file. Used by the readiness wait's local-exec kubectl call."
  type        = string
}

variable "talosconfig_raw" {
  description = "Raw talosconfig YAML. Mounted as a Secret into the etcd snapshot CronJob so talosctl can authenticate against the Talos API."
  type        = string
  sensitive   = true
}

variable "talos_cp_endpoints" {
  description = "Public IPv4 addresses of the Talos control-plane endpoints. The etcd snapshot CronJob targets the first one."
  type        = list(string)

  validation {
    condition     = length(var.talos_cp_endpoints) > 0
    error_message = "At least one Talos control-plane endpoint is required."
  }
}

variable "hcloud_object_storage_region" {
  description = "Hetzner Object Storage region (e.g., fsn1, nbg1, hel1). Becomes the host prefix in https://<region>.your-objectstorage.com."
  type        = string
}

variable "hcloud_s3_access_key" {
  description = "Hetzner Object Storage S3 access key. Generated once in the Hetzner Console — the hcloud Terraform provider doesn't manage S3 keys yet."
  type        = string
  sensitive   = true
}

variable "hcloud_s3_secret_key" {
  description = "Hetzner Object Storage S3 secret key."
  type        = string
  sensitive   = true
}

variable "bucket_name" {
  description = "Name of the S3 bucket Velero and the etcd CronJob write to. Convention: backups-<env_name>."
  type        = string
}

variable "velero_chart_version" {
  description = "vmware-tanzu/velero Helm chart version."
  type        = string
  default     = "12.0.1"
}

variable "velero_values" {
  description = "Rendered Helm values for vmware-tanzu/velero."
  type        = string
}

variable "etcd_snapshotter_image" {
  description = "Container image for the etcd snapshot CronJob. Must contain talosctl + aws CLI on PATH. Pin to a digest in production."
  type        = string
  # ghcr.io/sebastian-de/talosctl-aws bundles both binaries. Replace with our
  # own image once the platform registry (zot) is up.
  default = "ghcr.io/sebastian-de/talosctl-aws:0.1.0"
}

variable "etcd_snapshot_schedule" {
  description = "Cron schedule for the etcd snapshot CronJob. Default: every 6 hours."
  type        = string
  default     = "0 */6 * * *"
}

variable "etcd_snapshot_retention_days" {
  description = "How many days of etcd snapshots to retain in the bucket. Older objects under etcd/ are deleted by the CronJob's tail step."
  type        = number
  default     = 7
}
