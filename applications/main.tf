variable "cluster_connection" {
  type    = map(string)
  default = {}
}

variable "kube_config_yaml" {}

variable "gitlab_token" {}
variable "gitlab_project_id" {}
variable "domain" {}
variable "email" {}

terraform {
  required_providers {
    gitlab = {
      source = "gitlabhq/gitlab"
    }
    kustomization = {
      source  = "kbst/kustomization"
      version = "0.9.0"
    }
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "4.1.0"
    }
  }
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

provider "kustomization" {
  kubeconfig_raw = var.kube_config_yaml
}

provider "gitlab" {
  token = var.gitlab_token
}
