output "nodes" {
  description = "Generic node inventory consumed by the Talos cluster module."
  value = {
    control_plane = {
      for k, s in hcloud_server.control_plane : k => {
        name         = s.name
        ipv4         = hcloud_server_network.control_plane[k].ip
        public_ipv4  = hcloud_primary_ip.control_plane[k].ip_address
        install_disk = "/dev/sda"
        arch         = var.talos_image_labels["arch"]
        provider_id  = "hcloud://${s.id}"
      }
    }
    workers = {
      for k, s in hcloud_server.worker : k => {
        name         = s.name
        ipv4         = hcloud_server_network.worker[k].ip
        public_ipv4  = hcloud_primary_ip.worker[k].ip_address
        install_disk = "/dev/sda"
        arch         = var.talos_image_labels["arch"]
        provider_id  = "hcloud://${s.id}"
      }
    }
  }
}

output "network_id" {
  description = "Hetzner Cloud network ID."
  value       = hcloud_network.main.id
}

output "subnet_id" {
  description = "Hetzner Cloud subnet ID."
  value       = hcloud_network_subnet.main.id
}

output "firewall_id" {
  description = "Cluster firewall ID, or null if firewall is disabled (empty firewall_admin_ips)."
  value       = length(hcloud_firewall.cluster) > 0 ? hcloud_firewall.cluster[0].id : null
}

output "placement_group_id" {
  description = "Control-plane placement group ID."
  value       = hcloud_placement_group.control_plane.id
}

output "location" {
  description = "Hetzner Cloud location."
  value       = var.location
}

output "network_zone" {
  description = "Hetzner Cloud network zone (derived from location)."
  value       = local.network_zone
}
