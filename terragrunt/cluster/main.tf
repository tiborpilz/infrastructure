module "hcloud" {
  source = "./hcloud"

  env_name           = var.env_name
  location           = var.location
  network_cidr       = var.network_cidr
  subnet_cidr        = var.subnet_cidr
  talos_image_labels = var.talos_image_labels
  firewall_admin_ips = var.firewall_admin_ips

  control_plane_nodes = var.control_plane_nodes
  worker_nodes        = var.worker_nodes
}

module "talos" {
  source = "./talos"

  cluster_name     = var.cluster_name
  talos_version    = var.talos_version
  nodes            = module.hcloud.nodes
  kubeconfig_path  = var.kubeconfig_path
  talosconfig_path = var.talosconfig_path
}
