/**
 * # Extensions
 *
 * This module installs extensions to an already existing Kubernetes cluster.
 * For everything to work, the cluster needs to have Keycloak installed and set up.
 */

terraform {
  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "17.4.0"
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
      version = "4.3.1"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = "3.2.0"
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
