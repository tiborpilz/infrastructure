/**
 * # Foundation
 *
 * This module scaffolds a Kubernetes cluster.
 * Based on a node config, it will create Hetzner Cloud servers and connect external IPs to them.
 * Then, it will initialize the cluster using rke and install argocd, keycloak, cert-manager, ingress-nginx and metallb.
 */

module "hetzner" {
  source       = "./modules/hetzner"
  nodes        = var.nodes
  hcloud_token = var.secrets.hcloud_token
}

module "cloudflare" {
  source               = "./modules/cloudflare"
  nodes                = module.hetzner.nodes
  domain               = var.domain
  floating_ip          = module.hetzner.floating_ip
  cloudflare_api_token = var.secrets.cloudflare_api_token
}

module "cluster" {
  source                           = "./modules/cluster"
  nodes                            = module.hetzner.nodes
  ssh_key                          = module.hetzner.ssh_key
  domain                           = var.domain
  gitlab_infrastructure_project_id = var.gitlab_infrastructure_project_id
  gitlab_token                     = var.secrets.gitlab_token
  email                            = var.email
  versions                         = var.versions
  ingress_ips                      = [module.hetzner.floating_ip]
  keycloak_admin_password          = var.secrets.keycloak_admin_password
  hcloud_token                     = var.secrets.hcloud_token
}

output "domain" {
  value = var.domain
}

output "ssh_key" {
  value       = module.hetzner.ssh_key
  sensitive   = true
  description = "The generated SSH key for connecting to the nodes."
}

output "nodes" {
  value       = module.hetzner.nodes
  description = "Hetzner Cloud VMs with their respective roles."
}

output "ingress_ips" {
  value       = [module.hetzner.floating_ip]
  description = "List of ingress IPs."
}

output "kube_config_yaml" {
  sensitive   = true
  value       = module.cluster.kube_config_yaml
  description = "The generated kube config yaml"
}

output "cluster_connection" {
  sensitive   = true
  value       = module.cluster.cluster_connection
  description = "The cluster connection"
}
