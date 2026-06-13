output "pds_url" {
  description = "Public URL of the PDS service endpoint."
  value       = local.pds_url
}

output "pds_hostname" {
  description = "Hostname of the PDS service endpoint."
  value       = local.hostname
}

output "handle_hostnames" {
  description = "Handle hostnames routed to this PDS."
  value       = local.handle_hostnames
}

output "namespace" {
  description = "Namespace the PDS is installed in."
  value       = kubernetes_namespace.pds.metadata[0].name
}

output "admin_password" {
  description = "PDS admin password (basic auth user `admin`). Needed to mint invite codes."
  value       = random_bytes.admin_password.hex
  sensitive   = true
}

output "invite_code" {
  description = "Fresh single-use invite code, re-minted on every refresh."
  value       = jsondecode(data.http.invite_code.response_body).code
  sensitive   = true
}

output "ready" {
  description = "Sentinel that downstream layers can depend on once the PDS is healthy."
  value       = terraform_data.pds_ready.id != null
}
