locals {
  domain = "bababourbaki.dev"
  gitlab_project_id = "39120322"
}

inputs = {
  domain = local.domain
  gitlab_project_id = local.gitlab_project_id
}

generate "backend" {
  path = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
terraform {
  backend "http" {
    config  = {
      address = "https://gitlab.com/api/v4/projects/${local.gitlab_project_id}/terraform/state/${path_relative_to_include()}"
      lock_address = "https://gitlab.com/api/v4/projects/${local.gitlab_project_id}/terraform/state/${path_relative_to_include()}/lock"
      unlock_address = "https://gitlab.com/api/v4/projects/${local.gitlab_project_id}/terraform/state/${path_relative_to_include()}/lock"
      lock_method = "POST"
      unlock_method = "DELETE"
      retry_wait_min = "5"
    }
  }
}
EOF
}
