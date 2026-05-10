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
    cp-1 = {
      server_type = "cx43"
    }
  }

  # One worker, smallest type. Existence (not capacity) is what matters:
  # control-plane nodes are excluded from Hetzner LB Services, so a worker
  # gives the Gateway LoadBalancer at least one valid target.
  worker_nodes = {
    worker-1 = {
      server_type = "cx33"
    }
  }

  kubeconfig_path  = "${get_repo_root()}/.kube/${include.env.locals.cluster_name}.kubeconfig"
  talosconfig_path = "${get_repo_root()}/.talos/${include.env.locals.cluster_name}.talosconfig"
}
