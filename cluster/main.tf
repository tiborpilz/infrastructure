variable "metallb_secret" {}
variable "domain" {}
variable "hcloud_token" {}
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
      version = "1.4.1"
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
