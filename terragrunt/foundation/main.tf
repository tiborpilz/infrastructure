/**
 * # Foundation
 *
 * This module creates the foundation for a Kubernetes cluster.
 * Based on a node config, it will create Hetzner Cloud servers and connect external IPs to them.
 */

terraform {
  required_providers {
    rke = {
      source  = "rancher/rke"
      version = "1.4.1"
    }
  }
}

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

module "hetzner" {
  source = "./hetzner"
  nodes  = var.nodes
  hcloud_token = var.secrets.hcloud_token
}

module "cloudflare" {
  source = "./cloudflare"
  nodes  = module.hetzner.nodes
  domain = var.domain
  floating_ip = module.hetzner.floating_ip
  cloudflare_api_token = var.secrets.cloudflare_api_token
}

output "domain" {
  value = var.domain
}

output "ssh_key" {
  value     = module.hetzner.ssh_key
  sensitive = true
  description = "The generated SSH key for connecting to the nodes."
}

output "nodes" {
  value = module.hetzner.nodes
  description = "Hetzner Cloud VMs with their respective roles."
}

output "ingress_ips" {
  value = [module.hetzner.floating_ip]
  description = "List of ingress IPs."
}
