variable "metallb_secret" {}
variable "domain" {}
variable "hcloud_token" {}

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
      source = "rancher/rke"
    }
  }
  backend "http" {}
}
