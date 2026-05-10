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
    # Bucket management on Hetzner Object Storage. The aws provider works for
    # creates but errors on s3:GetPublicAccessBlock (Hetzner doesn't expose
    # that API), and signing-quirks make a few other resources flaky.
    minio = {
      source  = "aminueza/minio"
      version = "~> 3.0"
    }
  }
}
