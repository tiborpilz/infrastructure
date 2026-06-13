provider "helm" {}

module "hcloud_network" {
  source = "./hcloud/network"

  env_name           = var.env_name
  location           = var.location
  network_cidr       = var.network_cidr
  subnet_cidr        = var.subnet_cidr
  firewall_admin_ips = var.firewall_admin_ips
}

module "hcloud_server" {
  source = "./hcloud/server"

  env_name            = var.env_name
  location            = var.location
  talos_image_labels  = var.talos_image_labels
  control_plane_nodes = var.control_plane_nodes
  worker_nodes        = var.worker_nodes
  subnet_id           = module.hcloud_network.subnet_id
  firewall_ids        = module.hcloud_network.firewall_ids
}

locals {
  # First worker alphabetically gets the floating IP for ingress.
  ingress_worker = sort(keys(var.worker_nodes))[0]
}

resource "hcloud_floating_ip_assignment" "ingress" {
  floating_ip_id = module.hcloud_network.floating_ip_id
  server_id      = module.hcloud_server.worker_server_ids[local.ingress_worker]
}

module "talos" {
  source = "./talos"

  cluster_name             = var.cluster_name
  talos_version            = var.talos_version
  nodes                    = module.hcloud_server.nodes
  kubeconfig_path          = var.kubeconfig_path
  talosconfig_path         = var.talosconfig_path
  hcloud_token             = var.hcloud_token
  network_name             = module.hcloud_network.network_name
  domain                   = var.domain
  location                 = var.location
  cloudflare_api_token     = var.cloudflare_api_token
  admin_email              = var.admin_email
  floating_ip_address      = module.hcloud_network.floating_ip_address
  bootstrap_manifests_path = var.bootstrap_manifests_path
  authentik_secret_key     = var.authentik_secret_key
  argocd_age_key           = var.argocd_age_key
  hcloud_image_id          = tostring(module.hcloud_server.talos_image_id)
  hcloud_network_id        = tostring(module.hcloud_network.network_id)
  hcloud_firewall_id       = try(tostring(module.hcloud_network.firewall_ids[0]), "")
}

module "dns" {
  source = "./dns"

  domain  = var.domain
  lb_ipv4 = module.hcloud_network.floating_ip_address
  nodes   = module.hcloud_server.nodes
}
