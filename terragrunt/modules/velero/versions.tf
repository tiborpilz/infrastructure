terraform {
  required_version = ">= 1.7"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.36"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19"
    }
    # The aws provider here is just an S3 client. Hetzner Object Storage is
    # S3-compatible; we point the provider's endpoint at Hetzner's host. No
    # actual AWS account is involved.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
