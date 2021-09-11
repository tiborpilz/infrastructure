variable "metallb_secret" {}
variable "domain" {}
variable "hcloud_token" {}
variable "github_private_key_path" {}
variable "auth0_domain" {}
variable "auth0_client_id" {}
variable "auth0_client_secret" {}

variable nodes {
  type = map(any)
  default = {}
}
variable ssh_key {
  type = map(string)
  default = {}
}
variable ingress_ips {
  type = list(string)
  default = []
}


terraform {
  required_providers {
    rke = {
      source = "rancher/rke"
    }
    auth0 = {
      source = "alexkappa/auth0"
    }
  }
  backend "local" {}
}

provider "rke" {
  log_file = "${path.root}/log/rke.log"
}

provider "helm" {
  kubernetes {
    host = rke_cluster.cluster.api_server_url
    client_certificate = rke_cluster.cluster.client_cert
    client_key = rke_cluster.cluster.client_key
    cluster_ca_certificate = rke_cluster.cluster.ca_crt
  }
}

provider "kubernetes" {
  experiments {
    manifest_resource = true
  }

  host     = rke_cluster.cluster.api_server_url
  username = rke_cluster.cluster.kube_admin_user

  client_certificate     = rke_cluster.cluster.client_cert
  client_key             = rke_cluster.cluster.client_key
  cluster_ca_certificate = rke_cluster.cluster.ca_crt
}

provider "auth0" {
  domain = var.auth0_domain
  client_id = var.auth0_client_id
  client_secret = var.auth0_client_secret
}

output "cluster_connection" {
  value = {
    api_server_url = rke_cluster.cluster.api_server_url
    kube_admin_user = rke_cluster.cluster.kube_admin_user
    client_cert = rke_cluster.cluster.client_cert
    ca_crt = rke_cluster.cluster.ca_crt
    client_key = rke_cluster.cluster.client_key
  }
  sensitive = true
}
