include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  expose         = true
  merge_strategy = "no_merge"
}

terraform {
  source = "${get_repo_root()}//terragrunt/modules/machines/hcloud"
}

inputs = {
  env_name           = include.env.locals.env_name
  location           = include.env.locals.location
  network_cidr       = include.env.locals.network_cidr
  subnet_cidr        = include.env.locals.subnet_cidr
  talos_image_labels = include.env.locals.talos_image_labels
  firewall_admin_ips = include.env.locals.admin_ip_cidrs

  control_plane_nodes = {
    cp-1 = {
      server_type = "cx43"
    }
  }

  # One worker, smallest type. Existence (not capacity) is what matters —
  # the K8s "exclude-from-external-load-balancers" label is auto-applied to
  # CP nodes only, so a Hetzner LB Service needs at least one worker as a
  # target. cp-1 still schedules workloads (no NoSchedule taint), so this
  # worker is purely additive: it makes the LB work and gives a bit of
  # extra capacity.
  worker_nodes = {
    worker-1 = {
      server_type = "cx33"
    }
  }
}
