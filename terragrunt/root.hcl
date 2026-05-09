locals {
  repo_root = get_repo_root()
}

remote_state {
  backend = "local"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    path = "${local.repo_root}/.terragrunt-state/${path_relative_to_include()}/terraform.tfstate"
  }
}

# Provider configuration lives in each module (modules know which providers
# they need, and configs differ — e.g., hcloud uses HCLOUD_TOKEN env, talos
# auto-configures from machine_secrets, kubernetes/helm need cluster creds).
