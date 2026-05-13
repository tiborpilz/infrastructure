locals {
  effective_flake_host = var.flake_host != "" ? var.flake_host : var.name

  common_labels = merge({
    managed-by = "terragrunt"
    flavor     = "nixos"
  }, var.labels)
}

data "hcloud_ssh_keys" "selected" {
  with_selector = "managed-by=terragrunt"
}

locals {
  selected_ssh_keys = {
    for key in data.hcloud_ssh_keys.selected.ssh_keys :
    key.name => key
    if contains(var.ssh_key_names, key.name)
  }
  ssh_key_ids = [for name in var.ssh_key_names : local.selected_ssh_keys[name].id]
}

resource "hcloud_primary_ip" "this" {
  name              = "${var.name}-ipv4"
  type              = "ipv4"
  location          = var.location
  auto_delete       = false
  delete_protection = var.delete_protection
  labels            = local.common_labels
}

resource "hcloud_server" "this" {
  name               = var.name
  server_type        = var.server_type
  image              = var.bootstrap_image
  location           = var.location
  firewall_ids       = var.firewall_ids
  delete_protection  = var.delete_protection
  rebuild_protection = var.delete_protection
  ssh_keys           = local.ssh_key_ids

  public_net {
    ipv4_enabled = true
    ipv4         = hcloud_primary_ip.this.id
    ipv6_enabled = false
  }

  labels = local.common_labels

  lifecycle {
    # nixos-anywhere overwrites the boot disk on first run. Once installed,
    # `image` no longer reflects reality (it says "debian-12" but the server
    # is running NixOS). Ignore drift to keep applies clean.
    ignore_changes = [image, ssh_keys]
  }
}

resource "hcloud_server_network" "this" {
  count = var.network_id != null ? 1 : 0

  server_id  = hcloud_server.this.id
  network_id = var.network_id
  subnet_id  = var.subnet_id
  ip         = var.private_ipv4
}
