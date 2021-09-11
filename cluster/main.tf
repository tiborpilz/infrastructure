variable "metallb_secret" {}
variable "domain" {}
variable "hcloud_token" {}

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
  }
  backend "local" {}
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
