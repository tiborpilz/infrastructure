variable "metallb_secret" {}
variable "domain" {}

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
    client_cert = rke_cluster.cluster.client_cert
    ca_crt = rke_cluster.cluster.ca_crt
    client_key = rke_cluster.cluster.client_key
  }
  sensitive = true
}
