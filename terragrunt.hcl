terraform {
  extra_arguments "common_var" {
    commands = [
      "apply",
      "plan",
      "import",
      "push",
      "refresh"
    ]
    arguments = [
      "-var-file=${get_terragrunt_dir()}/${path_relative_from_include()}/common.tfvars",
    ]
  }
}

inputs = {
  domain = "tiborpilz.dev"
}
