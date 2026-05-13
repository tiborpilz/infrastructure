output "enabled" {
  description = "True if the Omni module is materialising resources. False when no GPG etcd key has been supplied via SOPS."
  value       = local.enabled
}

output "omni_url" {
  description = "Public URL where the Omni UI is reachable."
  value       = local.omni_url
}

output "omni_namespace" {
  description = "Namespace where Omni is installed (empty string when disabled)."
  value       = local.enabled ? kubernetes_namespace.omni[0].metadata[0].name : ""
}

output "siderolink_wireguard_endpoint" {
  description = "Endpoint configured as Omni's advertised SideroLink WireGuard endpoint."
  value       = var.siderolink_wireguard_endpoint
}

output "account_id" {
  description = "Generated Omni account UUID. Stable across applies; empty when disabled."
  value       = local.account_id
}

# output "ready" {
#   description = "Sentinel that downstream layers can depend on once Omni is healthy. True when module is disabled."
#   value       = local.enabled ? terraform_data.omni_ready[0].id != null : true
# }
