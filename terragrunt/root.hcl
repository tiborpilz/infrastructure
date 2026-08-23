locals {
  repo_root = get_repo_root()

  # Flip to false once all state is encrypted.
  state_encryption_migration = true

  secrets          = try(yamldecode(sops_decrypt_file("${local.repo_root}/terragrunt/secrets.enc.yaml")), {})
  state_passphrase = lookup(local.secrets, "state_passphrase", get_env("TF_STATE_PASSPHRASE", ""))

  # State lives in Cloudflare R2, reached over its S3-compatible API.
  r2_account_id = "65ecf0caf1b5e94e37b25f84e11e0a90"
  r2_bucket     = "tibor-infra-tfstate"
  r2_access_key = lookup(local.secrets, "r2_access_key_id", get_env("AWS_ACCESS_KEY_ID", ""))
  r2_secret_key = lookup(local.secrets, "r2_secret_access_key", get_env("AWS_SECRET_ACCESS_KEY", ""))
}

# Written by hand rather than through terragrunt's remote_state block: that block
# filters config keys against its own list for the s3 backend, and it does not
# know skip_s3_checksum or use_path_style, both of which R2 needs.
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      backend "s3" {
        bucket = "${local.r2_bucket}"
        key    = "${path_relative_to_include()}/terraform.tfstate"
        region = "auto"

        endpoints = {
          s3 = "https://${local.r2_account_id}.r2.cloudflarestorage.com"
        }

        # Locking via conditional writes on a .tflock object. R2 supports
        # If-None-Match, so this needs no second service.
        use_lockfile = true

        # R2 is not AWS: skip the credential, region and account probes, and
        # the trailing checksum header its S3 API rejects.
        skip_credentials_validation = true
        skip_metadata_api_check     = true
        skip_region_validation      = true
        skip_requesting_account_id  = true
        skip_s3_checksum            = true
        use_path_style              = true
      }
    }
  EOF
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

# The backend credentials are passed as environment variables so they never land
# in a generated backend.tf on disk.
terraform {
  extra_arguments "r2_backend_credentials" {
    commands = [
      "init",
      "validate",
      "plan",
      "apply",
      "destroy",
      "refresh",
      "import",
      "state",
      "output",
      "show",
      "console",
      "taint",
      "untaint",
      "force-unlock",
    ]

    env_vars = {
      AWS_ACCESS_KEY_ID     = local.r2_access_key
      AWS_SECRET_ACCESS_KEY = local.r2_secret_key
    }
  }
}

inputs = {
  state_passphrase = local.state_passphrase
}
