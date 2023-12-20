variable "secrets" {
  type    = map(string)
  default = {}
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

variable "domain" {}
variable "email" {}

variable "nodes" {
  type    = map(any)
  default = {}
}
variable "ssh_key" {
  type    = map(string)
  default = {}
}
variable "ingress_ips" {
  type    = list(string)
  default = []
}

variable "cluster_connection" {
  type    = map(string)
  default = {}
}

variable "kube_config_yaml" {
  type    = string
  default = ""
}


terraform {
  required_providers {
    rke = {
      source  = "rancher/rke"
      version = "1.4.3"
    }
  }
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
