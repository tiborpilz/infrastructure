variable "nodecount" {}
variable "hcloud_token" {}
variable "cloudflare_email" {}
variable "cloudflare_api_token" {}
variable "domain" {}
variable "docker_user" {}
variable "docker_password" {}
variable "docker_login" {
  type    = bool
  default = false
}

terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
  backend "local" {}
}

locals {
  names = [for i in range(var.nodecount) : format("%s%02d", "node", i)]
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
}

resource "local_file" "ssh_key" {
  filename = "${path.root}/../out/sshkey"
  content  = tls_private_key.ssh_key.private_key_pem
}

output "domain" {
  value = var.domain
}

output "ssh_key" {
  value = tls_private_key.ssh_key
  sensitive = true
}

output "nodes" {
  value = hcloud_server.nodes
}
