locals {
  common_labels = {
    env        = var.env_name
    managed-by = "terragrunt"
  }

  # Hetzner location → network_zone. Extend if adding new locations.
  network_zone_for_location = {
    fsn1 = "eu-central"
    nbg1 = "eu-central"
    hel1 = "eu-central"
    ash  = "us-east"
    hil  = "us-west"
    sin  = "ap-southeast"
  }

  network_zone = local.network_zone_for_location[var.location]

  # Hetzner uses x86/arm; Talos labels (and the rest of our stack) use amd64/arm64.
  hcloud_arch_for_talos_arch = {
    amd64 = "x86"
    arm64 = "arm"
  }
}

data "hcloud_image" "talos" {
  with_selector     = join(",", [for k, v in var.talos_image_labels : "${k}=${v}"])
  with_architecture = local.hcloud_arch_for_talos_arch[var.talos_image_labels["arch"]]
  most_recent       = true
}

resource "hcloud_network" "main" {
  name              = "${var.env_name}-main"
  ip_range          = var.network_cidr
  delete_protection = true
  labels            = local.common_labels
}

resource "hcloud_network_subnet" "main" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = local.network_zone
  ip_range     = var.subnet_cidr
}

resource "hcloud_placement_group" "control_plane" {
  name   = "${var.env_name}-control-plane"
  type   = "spread"
  labels = local.common_labels
}

# Workers get their own spread group so they land on different physical hosts
# from each other (and from the CP nodes, since these groups are independent).
resource "hcloud_placement_group" "workers" {
  count = length(var.worker_nodes) > 0 ? 1 : 0

  name   = "${var.env_name}-workers"
  type   = "spread"
  labels = local.common_labels
}

resource "hcloud_firewall" "cluster" {
  count = length(var.firewall_admin_ips) > 0 ? 1 : 0

  name   = "${var.env_name}-cluster"
  labels = local.common_labels

  # Talos API
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "50000"
    source_ips = var.firewall_admin_ips
  }

  # Kubernetes API
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "6443"
    source_ips = var.firewall_admin_ips
  }

  # ICMP from anywhere (handy for ping/MTU discovery)
  rule {
    direction  = "in"
    protocol   = "icmp"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_primary_ip" "cp" {
  for_each = var.control_plane_nodes

  name              = "${var.env_name}-${each.key}-ipv4"
  type              = "ipv4"
  location          = var.location
  auto_delete       = false
  delete_protection = true
  labels            = local.common_labels
}

resource "hcloud_server" "cp" {
  for_each = var.control_plane_nodes

  name               = each.key
  server_type        = each.value.server_type
  image              = data.hcloud_image.talos.id
  location           = var.location
  placement_group_id = hcloud_placement_group.control_plane.id
  firewall_ids       = hcloud_firewall.cluster[*].id

  public_net {
    ipv4_enabled = true
    ipv4         = hcloud_primary_ip.cp[each.key].id
    ipv6_enabled = false
  }

  # No user_data: Talos boots into maintenance mode; 10-cluster pushes config via talosctl.

  labels = merge(local.common_labels, {
    role          = "control-plane"
    talos-version = var.talos_image_labels["version"]
  })

  lifecycle {
    # Image updates flow through Talos itself (`talosctl upgrade`), not server recreate.
    ignore_changes = [image]
  }
}

resource "hcloud_server_network" "cp" {
  for_each = var.control_plane_nodes

  server_id = hcloud_server.cp[each.key].id
  subnet_id = hcloud_network_subnet.main.id
  ip        = each.value.private_ipv4

  depends_on = [hcloud_network_subnet.main]
}

# ---------------------------------------------------------------------------
# Worker nodes — same shape as control-plane resources, different placement
# group and labels. Workers don't get the K8s "exclude-from-external-LB"
# label, so a Hetzner LB Service can target them (which the single-node-only
# CP setup couldn't do).
# ---------------------------------------------------------------------------

resource "hcloud_primary_ip" "worker" {
  for_each = var.worker_nodes

  name              = "${var.env_name}-${each.key}-ipv4"
  type              = "ipv4"
  location          = var.location
  auto_delete       = false
  delete_protection = true
  labels            = local.common_labels
}

resource "hcloud_server" "worker" {
  for_each = var.worker_nodes

  name               = each.key
  server_type        = each.value.server_type
  image              = data.hcloud_image.talos.id
  location           = var.location
  placement_group_id = hcloud_placement_group.workers[0].id
  firewall_ids       = hcloud_firewall.cluster[*].id

  public_net {
    ipv4_enabled = true
    ipv4         = hcloud_primary_ip.worker[each.key].id
    ipv6_enabled = false
  }

  labels = merge(local.common_labels, {
    role          = "worker"
    talos-version = var.talos_image_labels["version"]
  })

  lifecycle {
    ignore_changes = [image]
  }
}

resource "hcloud_server_network" "worker" {
  for_each = var.worker_nodes

  server_id = hcloud_server.worker[each.key].id
  subnet_id = hcloud_network_subnet.main.id
  ip        = each.value.private_ipv4

  depends_on = [hcloud_network_subnet.main]
}
