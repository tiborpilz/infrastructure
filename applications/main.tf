variable "cluster_connection" {
  type = map(any)
  default = {}
}
variable domain {
  type = string
  default = ""
}

terraform {
  backend "local" {}
}

provider "kubernetes" {
  experiments {
    manifest_resource = true
  }

  host     = var.cluster_connection.api_server_url
  username = var.cluster_connection.kube_admin_user

  client_certificate     = var.cluster_connection.client_cert
  client_key             = var.cluster_connection.client_key
  cluster_ca_certificate = var.cluster_connection.ca_crt
}
