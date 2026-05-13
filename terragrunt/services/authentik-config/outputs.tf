output "platform_groups" {
  description = "Names of platform-level groups created in authentik. Downstream RBAC bindings can reference these by name."
  value       = sort([for group_name in var.platform_groups : authentik_group.platform[group_name].name])
}

output "managed_groups" {
  description = "All group names managed by this module, including groups referenced by managed users."
  value       = sort([for g in authentik_group.platform : g.name])
}

output "managed_users" {
  description = "Declarative managed users created in authentik, without passwords."
  value = {
    for username, user in authentik_user.managed : username => {
      name      = user.name
      email     = user.email
      is_active = user.is_active
      groups    = sort(tolist(local.managed_user_groups[username]))
      admin     = try(local.managed_users[username].admin, false)
    }
  }
}

output "managed_user_passwords" {
  description = "Managed user passwords keyed by username. Includes supplied and generated values."
  value       = local.managed_user_passwords
  sensitive   = true
}

output "bootstrap_users" {
  description = "Deprecated alias for managed_users."
  value = {
    for username, user in authentik_user.managed : username => {
      name      = user.name
      email     = user.email
      is_active = user.is_active
      groups    = sort(tolist(local.managed_user_groups[username]))
      admin     = try(local.managed_users[username].admin, false)
    }
  }
}

output "bootstrap_user_passwords" {
  description = "Deprecated alias for managed_user_passwords."
  value       = local.managed_user_passwords
  sensitive   = true
}
