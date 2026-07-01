output "network_id" {
  description = "Hetzner Cloud network ID."
  value       = hcloud_network.main.id
}

output "subnet_id" {
  description = "Hetzner Cloud subnet ID."
  value       = hcloud_network_subnet.main.id
}

output "firewall_ids" {
  description = "Cluster firewall IDs (empty list if firewall is disabled)."
  value       = hcloud_firewall.cluster[*].id
}

output "network_name" {
  description = "Hetzner Cloud private network name."
  value       = hcloud_network.main.name
}

output "floating_ip_id" {
  description = "Hetzner floating IP ID for the ingress node assignment."
  value       = hcloud_floating_ip.ingress.id
}

output "floating_ip_address" {
  description = "Public IPv4 of the ingress floating IP."
  value       = hcloud_floating_ip.ingress.ip_address
}
