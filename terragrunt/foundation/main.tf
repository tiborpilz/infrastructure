/**
 * # Foundation
 *
 * This module creates the foundation for a Kubernetes cluster.
 * Based on a node config, it will create Hetzner Cloud servers and connect external IPs to them.
 */

variable "secrets" {
  type    = map(string)
  default = {}
  description = "Encrypted secrets"
}
variable "nodes" {
  description = "Node configuration"
}
variable "domain" {
  type        = string
  description = "The domain to use"
}
variable "docker_login" {
  type    = bool
  default = false
  description = "Whether to login to docker"
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
  value = local.nodes_with_roles
  description = "Hetzner Cloud VMs with their respective roles."
}

output "ingress_ips" {
  value = [hcloud_floating_ip.floating_ip.ip_address]
  description = "List of ingress IPs."
}
