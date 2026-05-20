include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  expose         = true
  merge_strategy = "no_merge"
}

terraform {
  source = "."

  # The hcloud provider has no explicit `token =` config in the cluster
  # layer; it reads HCLOUD_TOKEN from the environment. Inject it from SOPS
  # (decrypted once in env.hcl, exposed via include.env.locals.secrets) so
  # the user/CI doesn't need to `export` anything before running.
  extra_arguments "secrets" {
    commands = get_terraform_commands_that_need_vars()
    env_vars = {
      HCLOUD_TOKEN = include.env.locals.secrets.hcloud_token
    }
  }
}

inputs = {
  env_name           = include.env.locals.env_name
  cluster_name       = include.env.locals.cluster_name
  location           = include.env.locals.location
  network_cidr       = include.env.locals.network_cidr
  subnet_cidr        = include.env.locals.subnet_cidr
  talos_image_labels = include.env.locals.talos_image_labels
  firewall_admin_ips = include.env.locals.admin_ip_cidrs
  talos_version      = include.env.locals.talos_version

  control_plane_nodes = {
    controlplane-1 = {
      server_type = "cpx32"
    }
  }

  # Static baseline worker. Burst capacity comes from cluster-autoscaler
  # (terragrunt/platform/cluster-autoscaler), which provisions cpx32 workers
  # in fsn1 up to a configured max.
  worker_nodes = {
    worker-1 = {
      server_type = "cpx22"
    }
  }

  kubeconfig_path  = "${get_repo_root()}/.kube/${include.env.locals.cluster_name}.kubeconfig"
  talosconfig_path = "${get_repo_root()}/.talos/${include.env.locals.cluster_name}.talosconfig"
}
