output "authentik_ready" {
  description = "Sentinel that downstream modules can depend on to wait for the authentik gate."
  value       = terraform_data.authentik_gate.output
}
