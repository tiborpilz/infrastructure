output "knot_url" {
  description = "Public URL where the tangled knot serves HTTPS (xrpc + web)."
  value       = local.enabled ? local.knot_url : ""
}

output "knot_hostname" {
  description = "Hostname users SSH to (git@<hostname>) and the HTTPS endpoint the appview verifies."
  value       = local.enabled ? local.hostname : ""
}

output "namespace" {
  description = "Namespace the knot is installed in. Empty when the module is dormant (owner_did unset)."
  value       = local.enabled ? kubernetes_namespace.tangled[0].metadata[0].name : ""
}

output "enabled" {
  description = "Whether the tangled module deployed resources. False when owner_did is empty."
  value       = local.enabled
}

output "ready" {
  description = "Sentinel that downstream layers can depend on once the knot is healthy."
  value       = local.enabled ? terraform_data.tangled_ready[0].id != null : true
}
