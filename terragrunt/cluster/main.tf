/**
 * # Cluster
 *
 * This module creates a kubernetes cluster using rke.
 * It also installs argocd, keycloak, cert-manager, ingress-nginx and metallb.
 */

variable "secrets" {
  type    = map(string)
  default = {}
  description = "The secrets to use"
}

variable "rke_kubernetes_version" {
  type        = string
  description = "The (rke) kubernetes version to use"
}

variable "keycloak_version" {
  type        = string
  description = "The keycloak version to use"
}

variable "cert_manager_version" {
  type        = string
  description = "The cert-manager version to use"
}

variable "ingress_nginx_version" {
  type        = string
  description = "The ingress-nginx version to use"
}

variable "metallb_version" {
  type        = string
  description = "The metallb version to use"
}

variable "gitlab_infrastructure_project_id" {
  description = "The id of the infrastructure project in gitlab"
}

variable "domain" {
  type = string
  description = "The domain to use"
}
variable "email" {
  type = string
  description = "The email used for letsencrypt"
}

variable "nodes" {
  type    = map(object({
    role         = string,
    ipv4_address = string
  }))
  description = "Kubernetes nodes."
}
variable "ssh_key" {
  type    = map(string)
  default = {}
  description = "SSH key to use for the k8s nodes."
}
variable "ingress_ips" {
  type    = list(string)
  default = []
  description = "List of ingress IPs to use for metallb."
}

variable "cluster_connection" {
  type    = map(string)
  default = {}
  description = "The cluster connection to use"
}

variable "kube_config_yaml" {
  type    = string
  default = ""
  description = "The kube config yaml to use"
}


terraform {
  required_providers {
    rke = {
      source  = "rancher/rke"
      version = "1.4.3"
    }
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "16.6.0"
    }
  }
}

provider "gitlab" {
  token = var.secrets.gitlab_token
}

output "kube_config_yaml" {
  sensitive = true
  value     = rke_cluster.cluster.kube_config_yaml
}

output "cluster_connection" {
  sensitive = true
  value = {
    host                   = rke_cluster.cluster.api_server_url
    cluster_ca_certificate = rke_cluster.cluster.ca_crt
    client_certificate     = rke_cluster.cluster.client_cert
    client_key             = rke_cluster.cluster.client_key
  }
}
