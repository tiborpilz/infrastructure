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

# S3 client pointed at Hetzner Object Storage. The aws provider is the
# best-supported S3 client in the Terraform registry; the "aws" name is a
# misnomer here. All AWS-specific lookups (STS, metadata, account ID) are
# disabled because Hetzner doesn't speak them.
provider "aws" {
  region     = var.hcloud_object_storage_region
  access_key = var.hcloud_s3_access_key
  secret_key = var.hcloud_s3_secret_key

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true

  s3_use_path_style = true

  endpoints {
    s3 = "https://${var.hcloud_object_storage_region}.your-objectstorage.com"
  }
}
