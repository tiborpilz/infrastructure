provider "helm" {}

provider "proxmox" {
  insecure = var.proxmox_insecure

  ssh {
    agent    = false
    username = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
  }
}

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

  proxmox_workers = {
    for name, w in var.proxmox_workers : name => {
      ip           = w.ip
      install_disk = w.install_disk
    }
  }
  proxmox_network_gateway    = var.proxmox_network_gateway
  proxmox_network_cidr       = var.proxmox_network_cidr
  proxmox_nameservers        = var.proxmox_nameservers
  proxmox_talos_schematic_id = var.proxmox_talos_schematic_id
}

module "proxmox_server" {
  source = "./proxmox/server"
  count  = length(var.proxmox_workers) > 0 ? 1 : 0

  proxmox_node       = var.proxmox_node
  image_datastore    = var.proxmox_image_datastore
  vm_datastore       = var.proxmox_vm_datastore
  snippets_datastore = var.proxmox_snippets_datastore
  network_bridge     = var.proxmox_network_bridge
  network_gateway    = var.proxmox_network_gateway
  network_cidr       = var.proxmox_network_cidr
  nameservers        = var.proxmox_nameservers
  talos_version      = var.talos_version
  talos_schematic_id = var.proxmox_talos_schematic_id
  kubeconfig_path    = var.kubeconfig_path

  workers = {
    for name, w in var.proxmox_workers : name => {
      vm_id          = w.vm_id
      ip             = w.ip
      cores          = w.cores
      memory         = w.memory
      disk_size      = w.disk_size
      data_disk_size = w.data_disk_size
    }
  }
  worker_machine_configs = module.talos.proxmox_worker_machine_configs
}

module "dns" {
  source = "./dns"

  domain  = var.domain
  lb_ipv4 = module.hcloud_network.floating_ip_address
  nodes   = module.hcloud_server.nodes
}
