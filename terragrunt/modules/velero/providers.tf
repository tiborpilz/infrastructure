provider "kubernetes" {
  host                   = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key
}

provider "kubectl" {
  host                   = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key
  load_config_file       = false
}

# S3 client pointed at Hetzner Object Storage. The minio provider speaks the
# S3 wire protocol and skips the AWS-only IAM/STS plumbing the aws provider
# tries (and fails) to use against Hetzner.
provider "minio" {
  minio_server   = "${var.hcloud_object_storage_region}.your-objectstorage.com"
  minio_user     = var.hcloud_s3_access_key
  minio_password = var.hcloud_s3_secret_key
  minio_ssl      = true
  minio_region   = var.hcloud_object_storage_region
}
