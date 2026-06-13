locals {
  common_labels = {
    env        = var.env_name
    managed-by = "terragrunt"
  }

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

resource "hcloud_placement_group" "control_plane" {
  name   = "${var.env_name}-control-plane"
  type   = "spread"
  labels = local.common_labels
}

resource "hcloud_placement_group" "workers" {
  count = length(var.worker_nodes) > 0 ? 1 : 0

  name   = "${var.env_name}-workers"
  type   = "spread"
  labels = local.common_labels
}

resource "hcloud_primary_ip" "control_plane" {
  for_each = var.control_plane_nodes

  name              = "${var.env_name}-${each.key}-ipv4"
  type              = "ipv4"
  location          = var.location
  auto_delete       = false
  delete_protection = false
  labels            = local.common_labels
}

resource "hcloud_server" "control_plane" {
  for_each = var.control_plane_nodes

  name               = each.key
  server_type        = each.value.server_type
  image              = data.hcloud_image.talos.id
  location           = var.location
  placement_group_id = hcloud_placement_group.control_plane.id
  firewall_ids       = var.firewall_ids

  public_net {
    ipv4_enabled = true
    ipv4         = hcloud_primary_ip.control_plane[each.key].id
    ipv6_enabled = false
  }

  labels = merge(local.common_labels, {
    role          = "control-plane"
    talos-version = var.talos_image_labels["version"]
  })

  lifecycle {
    ignore_changes = [image]
  }
}

resource "hcloud_server_network" "control_plane" {
  for_each = var.control_plane_nodes

  server_id = hcloud_server.control_plane[each.key].id
  subnet_id = var.subnet_id
  ip        = each.value.private_ipv4
}

resource "hcloud_primary_ip" "worker" {
  for_each = var.worker_nodes

  name              = "${var.env_name}-${each.key}-ipv4"
  type              = "ipv4"
  location          = var.location
  auto_delete       = false
  delete_protection = false
  labels            = local.common_labels
}

resource "hcloud_server" "worker" {
  for_each = var.worker_nodes

  name               = each.key
  server_type        = each.value.server_type
  image              = data.hcloud_image.talos.id
  location           = var.location
  placement_group_id = hcloud_placement_group.workers[0].id
  firewall_ids       = var.firewall_ids

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
  subnet_id = var.subnet_id
  ip        = each.value.private_ipv4
}

resource "hcloud_volume" "worker" {
  for_each = { for k, v in var.worker_nodes : k => v if v.volume_size_gb != null }

  name      = "${var.env_name}-${each.key}-data"
  size      = each.value.volume_size_gb
  server_id = hcloud_server.worker[each.key].id
  automount = false
  labels    = local.common_labels
}
