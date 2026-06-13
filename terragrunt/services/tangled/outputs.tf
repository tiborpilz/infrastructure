output "knot_url" {
  description = "Public URL where the tangled knot serves HTTPS (xrpc + web)."
  value       = local.enabled ? local.knot_url : ""
}

output "knot_hostname" {
  description = "Hostname users SSH to (git@<hostname>) and the HTTPS endpoint the appview verifies."
  value       = local.enabled ? local.hostname : ""
}

output "namespace" {
  description = "Namespace the knot is installed in. Empty when the module is dormant."
  value       = local.enabled ? kubernetes_namespace.tangled[0].metadata[0].name : ""
}

output "owner_did" {
  description = "Computed did:web identifier for the knot owner."
  value       = local.enabled ? local.owner_did : ""
}

output "did_document_url" {
  description = "Public URL where the did:web document is served."
  value       = local.enabled ? "https://${local.did_hostname}/.well-known/did.json" : ""
}

output "enabled" {
  description = "Whether the tangled module deployed resources. False when owner_handle or owner_signing_key_multibase is unset."
  value       = local.enabled
}

output "ready" {
  description = "Sentinel that downstream layers can depend on once the knot is healthy."
  value       = local.enabled ? terraform_data.tangled_ready[0].id != null : true
}
