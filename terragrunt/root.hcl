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
