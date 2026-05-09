locals {
  # `var.authentik_ready` is consumed by terragrunt's dependency graph (the
  # env layer reads dependency.authentik.outputs.ready). Declared but not
  # referenced inside resources by design — ordering is enforced at the
  # layer boundary.
}

# ---------------------------------------------------------------------------
# Platform-level groups. These are intentionally empty: membership is added
# manually in the authentik UI (or by a future user-provisioning flow), and
# downstream RBAC bindings (e.g., a ClusterRoleBinding for cluster-admin)
# reference these groups by name.
#
# The `akadmin` password is already pinned by `40-authentik` via the
# AUTHENTIK_BOOTSTRAP_PASSWORD env var sourced from a `random_password`
# resource. The bootstrap loop in the authentik worker re-applies that
# password on every start, so this layer doesn't need to manage it.
# ---------------------------------------------------------------------------

resource "authentik_group" "platform" {
  for_each = toset(var.platform_groups)

  name = each.key
}
