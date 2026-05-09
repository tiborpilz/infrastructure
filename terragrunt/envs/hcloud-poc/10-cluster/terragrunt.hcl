include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  expose         = true
  merge_strategy = "no_merge"
}

terraform {
  source = "${get_repo_root()}//terragrunt/modules/cluster/talos"
}

dependency "machines" {
  config_path = "../00-machines"

  # Mock outputs let `terragrunt validate`, `plan`, and `init` succeed
  # before 00-machines has been applied.
  mock_outputs = {
    nodes = {
      control_plane = {
        cp-1 = {
          name         = "cp-1"
          ipv4         = "10.0.0.2"
          public_ipv4  = "203.0.113.1"
          install_disk = "/dev/sda"
          arch         = "amd64"
          provider_id  = "hcloud://0"
        }
      }
      workers = {}
    }
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "console"]
}

inputs = {
  cluster_name  = include.env.locals.cluster_name
  talos_version = include.env.locals.talos_version
  nodes         = dependency.machines.outputs.nodes
  # cluster_endpoint left null — module derives it from first CP node's public IPv4.

  # Write kubeconfig + talosconfig to disk on apply, scoped per cluster name
  # under the repo root. Both directories are gitignored.
  kubeconfig_path  = "${get_repo_root()}/.kube/${include.env.locals.cluster_name}.kubeconfig"
  talosconfig_path = "${get_repo_root()}/.talos/${include.env.locals.cluster_name}.talosconfig"
}
