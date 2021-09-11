variable "github_private_key_path" {}
variable "auth0_domain" {}
variable "auth0_client_id" {}
variable "auth0_client_secret" {}
variable "cluster_connection" {
  type = map(any)
  default = {}
}

terraform {
  required_providers {
    auth0 = {
      source = "alexkappa/auth0"
    }
  }
  backend "local" {}
}

provider "helm" {
  kubernetes {
    host = var.cluster_connection.api_server_url
    client_certificate = var.cluster_connection.client_cert
    client_key = var.cluster_connection.client_key
    cluster_ca_certificate = var.cluster_connection.ca_crt
  }
}

provider "auth0" {
  domain = var.auth0_domain
  client_id = var.auth0_client_id
  client_secret = var.auth0_client_secret
}
