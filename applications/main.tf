variable "cluster_connection" {
  type    = map(string)
  default = {}
}

variable "gitlab_token" {}
variable "gitlab_project_id" {}

terraform {
  required_providers {
    gitlab = {
      source = "gitlabhq/gitlab"
    }
  }

  backend "http" {}
}

provider "kubernetes" {
  host                   = var.cluster_connection.host
  client_certificate     = var.cluster_connection.client_certificate
  client_key             = var.cluster_connection.client_key
  cluster_ca_certificate = var.cluster_connection.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = var.cluster_connection.host
    client_certificate     = var.cluster_connection.client_certificate
    client_key             = var.cluster_connection.client_key
    cluster_ca_certificate = var.cluster_connection.cluster_ca_certificate
  }
}


provider "gitlab" {
  token = var.gitlab_token
}
