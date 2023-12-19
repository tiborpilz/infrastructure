variable "secrets" {
  type    = map(string)
  default = {}
}
variable "nodecount" {}
variable "domain" {}
variable "docker_login" {
  type    = bool
  default = false
}
variable "metallb_secret" {
  type    = string
  default = ""
}

terraform {
  required_providers {
    rke = {
      source  = "rancher/rke"
      version = "1.4.1"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.39.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.6.0"
    }
  }
}

locals {
  names = [for i in range(var.nodecount) : format("%s%02d", "node", i)]
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
}

resource "local_file" "ssh_key" {
  filename        = "${path.root}/../out/sshkey"
  content         = tls_private_key.ssh_key.private_key_pem
  file_permission = "0600"
}

output "domain" {
  value = var.domain
}

output "ssh_key" {
  value     = tls_private_key.ssh_key
  sensitive = true
}

output "nodes" {
  value = hcloud_server.nodes
}

output "ingress_ips" {
  value = [hcloud_floating_ip.floating_ip.ip_address]
}
