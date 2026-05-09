output "platform_groups" {
  description = "Names of platform-level groups created in authentik. Downstream RBAC bindings can reference these by name."
  value       = [for g in authentik_group.platform : g.name]
}
