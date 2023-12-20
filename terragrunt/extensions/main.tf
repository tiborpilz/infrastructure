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

variable "users" {
  type = map(object({
    username   = string
    password   = string
    email      = string
    is_admin   = bool
    first_name = string
    last_name  = string
  }))
}

variable "gitlab_infrastructure_project_id" {
  description = "The id of the infrastructure project in gitlab"
}

terraform {
  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "16.6.0"
    }
    kustomization = {
      source  = "kbst/kustomization"
      version = "0.9.5"
    }
    argocd = {
      source  = "oboukili/argocd"
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

provider "keycloak" {
  client_id = "admin-cli"
  username  = "admin"
  password  = var.secrets.keycloak_admin_password
  url       = "https://keycloak.${var.domain}/"
}

module "keycloak" {
  source         = "./modules/keycloak"
  domain         = var.domain
  admin_password = var.secrets.keycloak_admin_password
  users          = var.users
}

module "argocd" {
  source                           = "./modules/argocd"
  keycloak_realm                   = module.keycloak.realm
  domain                           = var.domain
  argocd_version                   = var.argocd_version
  gitlab_infrastructure_project_id = var.gitlab_infrastructure_project_id
  kube_config_yaml                 = var.kube_config_yaml
}
