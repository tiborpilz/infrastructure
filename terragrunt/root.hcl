locals {
  repo_root = get_repo_root()

  # Flip to false once all state is encrypted.
  state_encryption_migration = true

  secrets          = try(yamldecode(sops_decrypt_file("${local.repo_root}/terragrunt/secrets.enc.yaml")), {})
  state_passphrase = lookup(local.secrets, "state_passphrase", get_env("TF_STATE_PASSPHRASE", ""))
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

generate "state_encryption" {
  path      = "encryption.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    variable "state_passphrase" {
      type      = string
      sensitive = true
    }

    terraform {
      encryption {
        key_provider "pbkdf2" "state" {
          passphrase = var.state_passphrase
        }

        method "aes_gcm" "state" {
          keys = key_provider.pbkdf2.state
        }
    %{if local.state_encryption_migration~}
        method "unencrypted" "migration" {}

        state {
          method = method.aes_gcm.state
          fallback {
            method = method.unencrypted.migration
          }
        }

        plan {
          method = method.aes_gcm.state
          fallback {
            method = method.unencrypted.migration
          }
        }
    %{else~}
        state {
          method   = method.aes_gcm.state
          enforced = true
        }

        plan {
          method   = method.aes_gcm.state
          enforced = true
        }
    %{endif~}
      }
    }
  EOF
}

inputs = {
  state_passphrase = local.state_passphrase
}
