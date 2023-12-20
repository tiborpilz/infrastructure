locals {
  email                            = "tibor@pilz.berlin"
  domain                           = "tbr.gg"
  gitlab_infrastructure_project_id = "53191844"
  secrets                          = yamldecode(file("${get_parent_terragrunt_dir()}/secrets.yaml"))
}

inputs = {
  email                            = local.email
  domain                           = local.domain
  gitlab_infrastructure_project_id = local.gitlab_infrastructure_project_id
  secrets                          = local.secrets
}

retryable_errors = [
  "(?s).*error initializing keycloak provider*" # sometimes we need to wait for the certificates to be ready
]

retry_max_attempts       = 5
retry_sleep_interval_sec = 10

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "http" {
    address        = "${get_env("TF_STATE_BASE_ADDRESS", "https://gitlab.com/api/v4/projects/${local.gitlab_infrastructure_project_id}/terraform/state")}/${path_relative_to_include()}"
    lock_address   = "${get_env("TF_STATE_BASE_ADDRESS", "https://gitlab.com/api/v4/projects/${local.gitlab_infrastructure_project_id}/terraform/state")}/${path_relative_to_include()}/lock"
    unlock_address = "${get_env("TF_STATE_BASE_ADDRESS", "https://gitlab.com/api/v4/projects/${local.gitlab_infrastructure_project_id}/terraform/state")}/${path_relative_to_include()}/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = "5"
  }
}
EOF
}
