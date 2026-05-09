include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  expose         = true
  merge_strategy = "no_merge"
}

terraform {
  source = "${get_repo_root()}//terragrunt/modules/authentik-config"
}

dependency "authentik" {
  config_path = "../40-authentik"

  mock_outputs = {
    authentik_url         = "https://auth.example.com"
    bootstrap_admin_token = "mock-token"
    ready                 = true
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

inputs = {
  authentik_url              = dependency.authentik.outputs.authentik_url
  authentik_token            = dependency.authentik.outputs.bootstrap_admin_token
  authentik_ready            = dependency.authentik.outputs.ready
  managed_users              = include.env.locals.managed_users
  managed_user_passwords     = include.env.locals.managed_user_passwords
  platform_admin_groups      = include.env.locals.platform_admin_groups
  authentik_superuser_groups = include.env.locals.authentik_superuser_groups
}
