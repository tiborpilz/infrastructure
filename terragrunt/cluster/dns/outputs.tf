output "node_fqdns" {
  description = "Map of node name to FQDN."
  value       = { for k, r in cloudflare_record.node : k => "${r.name}.${local.zone}" }
}
