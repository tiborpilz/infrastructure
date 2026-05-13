output "server_id" {
  description = "Hetzner Cloud server ID."
  value       = hcloud_server.this.id
}

output "name" {
  description = "Server name / Hetzner identifier."
  value       = hcloud_server.this.name
}

output "public_ipv4" {
  description = "Public IPv4 address. Stable across reboots; deletion protected by default."
  value       = hcloud_primary_ip.this.ip_address
}

output "private_ipv4" {
  description = "Private IPv4 inside the attached subnet. Null when network_id is unset."
  value       = var.network_id != null ? var.private_ipv4 : null
}

output "flake_host" {
  description = "Flake host name installed on the server. Use with `deploy .#<flake_host>` for ongoing updates."
  value       = local.effective_flake_host
}

output "bootstrap_id" {
  description = "ID of the nixos-anywhere bootstrap run. Changes when the server is replaced."
  value       = terraform_data.nixos_anywhere.id
}
