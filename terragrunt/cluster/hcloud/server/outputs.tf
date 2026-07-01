output "nodes" {
  description = "Cluster node inventory consumed by the Talos cluster module."
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

output "worker_server_ids" {
  description = "Map of worker name to Hetzner server ID."
  value       = { for k, s in hcloud_server.worker : k => s.id }
}

output "location" {
  description = "Hetzner Cloud location."
  value       = var.location
}

output "talos_image_id" {
  description = "Numeric Hetzner Cloud snapshot ID for the Talos image currently in use. Consumed by cluster-autoscaler to bootstrap new workers from the same image as Terraform-provisioned nodes."
  value       = data.hcloud_image.talos.id
}
