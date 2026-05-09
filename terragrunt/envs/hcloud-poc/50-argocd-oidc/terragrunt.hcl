include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  expose         = true
  merge_strategy = "no_merge"
}

terraform {
  source = "${get_repo_root()}//terragrunt/modules/argocd-oidc"
}

dependency "argocd" {
  config_path = "../20-argocd"

  mock_outputs = {
    argocd_url                = "https://argocd.example.com"
    argocd_oidc_client_id     = "argocd"
    argocd_oidc_client_secret = "mock"
    argocd_oidc_redirect_uri  = "https://argocd.example.com/auth/callback"
  }
  # `shallow` merge fills in missing keys from mocks even when state exists.
  # Necessary here because 20-argocd already has applied state from before
  # these new outputs were declared; without merging, validate fails on
  # "no such attribute" until 20-argocd is re-applied.
  mock_outputs_merge_strategy_with_state = "shallow"
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
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
  authentik_url   = dependency.authentik.outputs.authentik_url
  authentik_token = dependency.authentik.outputs.bootstrap_admin_token
  authentik_ready = dependency.authentik.outputs.ready

  argocd_url                = dependency.argocd.outputs.argocd_url
  argocd_oidc_client_id     = dependency.argocd.outputs.argocd_oidc_client_id
  argocd_oidc_client_secret = dependency.argocd.outputs.argocd_oidc_client_secret
  argocd_oidc_redirect_uri  = dependency.argocd.outputs.argocd_oidc_redirect_uri
}
