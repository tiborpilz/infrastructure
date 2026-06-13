locals {
  common_labels = {
    env        = var.env_name
    managed-by = "terragrunt"
  }
}

resource "hcloud_network" "main" {
  name     = "${var.env_name}-main"
  ip_range = var.network_cidr
  labels   = local.common_labels
}

resource "hcloud_network_subnet" "main" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = var.subnet_cidr
}

resource "hcloud_floating_ip" "ingress" {
  name          = "${var.env_name}-ingress"
  type          = "ipv4"
  home_location = var.location
  labels        = local.common_labels
}

resource "hcloud_firewall" "cluster" {
  count = length(var.firewall_admin_ips) > 0 ? 1 : 0

  name   = "${var.env_name}-cluster"
  labels = local.common_labels

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "50000" # Talos API
    source_ips = var.firewall_admin_ips
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "6443" # Kubernetes API
    source_ips = var.firewall_admin_ips
  }

  # Allow pings so I don't lose my mind
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # Required for Talos to bootstrap other cluster nodes.
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "30180"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}
