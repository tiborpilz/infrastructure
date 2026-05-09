locals {
  # `var.authentik_ready` is consumed by terragrunt's dependency graph (the
  # env layer reads dependency.authentik.outputs.ready). Declared but not
  # referenced inside resources by design — ordering is enforced at the
  # layer boundary.
  managed_users = merge(var.bootstrap_users, var.managed_users)

  managed_user_password_inputs = merge(
    var.bootstrap_user_passwords,
    var.managed_user_passwords,
  )

  managed_user_group_names = distinct(flatten([
    for user in local.managed_users : concat(
      try(user.groups, []),
      try(user.admin, false) ? var.platform_admin_groups : [],
    )
  ]))

  managed_group_names = toset(distinct(concat(
    var.platform_groups,
    var.platform_admin_groups,
    var.authentik_superuser_groups,
    local.managed_user_group_names,
  )))

  managed_user_groups = {
    for username, user in local.managed_users : username => toset(distinct(concat(
      try(user.groups, []),
      try(user.admin, false) ? var.platform_admin_groups : [],
    )))
  }

  managed_group_usernames = {
    for group_name in local.managed_group_names : group_name => sort([
      for username, groups in local.managed_user_groups : username
      if contains(groups, group_name)
    ])
  }

  supplied_managed_usernames = toset(nonsensitive(keys(local.managed_user_password_inputs)))

  generated_managed_user_passwords = {
    for username, password in random_password.managed_user : username => password.result
  }

  supplied_managed_user_passwords = {
    for username, password in local.managed_user_password_inputs : username => password
    if contains(keys(local.managed_users), username)
  }

  managed_user_passwords = merge(
    local.generated_managed_user_passwords,
    local.supplied_managed_user_passwords,
  )
}

# ---------------------------------------------------------------------------
# Platform-level groups and managed users. Once `managed_users` is set,
# membership of managed groups is declarative for those users; keep purely
# manual groups outside this module.
#
# The `akadmin` password is already pinned by `40-authentik` via the
# AUTHENTIK_BOOTSTRAP_PASSWORD env var sourced from a `random_password`
# resource. The bootstrap loop in the authentik worker re-applies that
# password on every start, so this layer doesn't need to manage it.
# ---------------------------------------------------------------------------

moved {
  from = random_password.bootstrap_user
  to   = random_password.managed_user
}

moved {
  from = authentik_user.bootstrap
  to   = authentik_user.managed
}

resource "random_password" "managed_user" {
  for_each = {
    for username, user in local.managed_users : username => user
    if !contains(local.supplied_managed_usernames, username)
  }

  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "authentik_user" "managed" {
  for_each = local.managed_users

  username  = each.key
  name      = each.value.name
  email     = each.value.email
  is_active = try(each.value.is_active, true)
  path      = try(each.value.path, "users/managed")
  type      = "internal"
  password  = local.managed_user_passwords[each.key]

  attributes = jsonencode(merge(
    try(each.value.attributes, {}),
    {
      "managed-by" = "terraform"
    },
  ))
}

resource "authentik_group" "platform" {
  for_each = local.managed_group_names

  name         = each.key
  is_superuser = contains(var.authentik_superuser_groups, each.key)
  users = length(local.managed_users) > 0 ? [
    for username in local.managed_group_usernames[each.key] :
    authentik_user.managed[username].id
  ] : null
}
