variable "secrets" {
  type    = map(string)
  default = {}
}

variable "cluster_connection" {
  type    = map(string)
  default = {}
}

variable "kube_config_yaml" {}

variable "domain" {}
variable "email" {}

variable "rancher_version" {
  type        = string
  description = "The rancher (helm chart) version to use"
}

variable "argocd_version" {
  type        = string
  description = "The argocd (helm chart) version to use"
}

terraform {
  required_providers {
    gitlab = {
      source = "gitlabhq/gitlab"
    }
    kustomization = {
      source  = "kbst/kustomization"
      version = "0.9.0"
    }
    argocd = {
      source = "oboukili/argocd"
      version = "6.0.3"
    }
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "4.1.0"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = "3.0.0"
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
  token = var.secrets.gitlab_token
}
