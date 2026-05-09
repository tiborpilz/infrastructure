include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  expose         = true
  merge_strategy = "no_merge"
}

terraform {
  source = "${get_repo_root()}//terragrunt/modules/velero"
}

dependency "cluster" {
  config_path = "../10-cluster"

  mock_outputs = {
    kubernetes_host        = "https://203.0.113.1:6443"
    cluster_ca_certificate = "mock-ca"
    client_certificate     = "mock-cert"
    client_key             = "mock-key"
    talosconfig            = "mock-talosconfig"
    talos_cp_endpoints     = ["203.0.113.1"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]

  # Fill in fields the cached state doesn't yet have (e.g., new
  # talos_cp_endpoints output until 10-cluster is re-applied). Without this,
  # missing keys raise "Unsupported attribute" instead of falling back to
  # the mock above.
  mock_outputs_merge_strategy_with_state = "shallow"
}

# 20-argocd installs Argo CD (whose Application CRD we use). No outputs
# consumed but order matters at apply time.
dependency "argocd" {
  config_path                             = "../20-argocd"
  skip_outputs                            = true
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

# Backups should be wired up before stateful workloads land — gate on
# platform-data being healthy so the bucket + Velero exist by the time
# authentik (40) starts producing data worth backing up.
dependency "platform_data" {
  config_path = "../35-platform-data"

  mock_outputs = {
    ready = true
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

inputs = {
  kubernetes_host        = dependency.cluster.outputs.kubernetes_host
  cluster_ca_certificate = dependency.cluster.outputs.cluster_ca_certificate
  client_certificate     = dependency.cluster.outputs.client_certificate
  client_key             = dependency.cluster.outputs.client_key

  talosconfig_raw    = dependency.cluster.outputs.talosconfig
  talos_cp_endpoints = dependency.cluster.outputs.talos_cp_endpoints

  # Hetzner Object Storage region. Defaults to the cluster location so
  # backup writes stay in-region. Override here if S3 creds are scoped to
  # a different region.
  hcloud_object_storage_region = include.env.locals.location

  # S3 access keys are NOT yet creatable via the hcloud Terraform provider.
  # Generate them in the Hetzner Console once and export the env vars.
  # Migrate to SOPS in M2.
  hcloud_s3_access_key = get_env("HCLOUD_S3_ACCESS_KEY", "")
  hcloud_s3_secret_key = get_env("HCLOUD_S3_SECRET_KEY", "")

  bucket_name = "backups-${include.env.locals.env_name}"

  velero_values = templatefile(
    "${get_repo_root()}/applications/velero/values.yaml.tpl",
    {
      bucket_name = "backups-${include.env.locals.env_name}"
      region      = include.env.locals.location
    }
  )
}
