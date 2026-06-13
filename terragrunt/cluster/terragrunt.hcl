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

  extra_arguments "secrets" {
    commands = get_terraform_commands_that_need_vars()
    env_vars = {
      HCLOUD_TOKEN         = include.env.locals.secrets.hcloud_token
      CLOUDFLARE_API_TOKEN = include.env.locals.secrets.cloudflare_api_token
    }
  }
}

inputs = {
  env_name             = include.env.locals.env_name
  cluster_name         = include.env.locals.cluster_name
  location             = include.env.locals.location
  network_cidr         = include.env.locals.network_cidr
  subnet_cidr          = include.env.locals.subnet_cidr
  talos_image_labels   = include.env.locals.talos_image_labels
  firewall_admin_ips   = include.env.locals.admin_ip_cidrs
  talos_version        = include.env.locals.talos_version
  domain               = include.env.locals.domain
  admin_email          = include.env.locals.acme_email
  cloudflare_api_token = include.env.locals.secrets.cloudflare_api_token
  hcloud_token         = include.env.locals.secrets.hcloud_token
  authentik_secret_key = include.env.locals.secrets.authentik_secret_key
  argocd_age_key       = include.env.locals.argocd_age_key

  control_plane_nodes = {
    controlplane-1 = {
      server_type = "cx23"
    }
    controlplane-2 = {
      server_type = "cx23"
    }
    controlplane-3 = {
      server_type = "cx23"
    }
  }

  worker_nodes = {
    worker-1 = {
      server_type = "cx33"
    }
    # worker-2/3/4: Ceph OSD nodes. 50 GB raw volume each backs Rook-Ceph OSDs.
    worker-2 = {
      server_type    = "cx23"
      volume_size_gb = 50
    }
    worker-3 = {
      server_type    = "cx23"
      volume_size_gb = 50
    }
    worker-4 = {
      server_type    = "cx23"
      volume_size_gb = 50
    }
  }

  kubeconfig_path          = "${get_repo_root()}/.kube/${include.env.locals.cluster_name}.kubeconfig"
  talosconfig_path         = "${get_repo_root()}/.talos/${include.env.locals.cluster_name}.talosconfig"
  bootstrap_manifests_path = "${get_repo_root()}/.kube/${include.env.locals.cluster_name}-bootstrap-manifests.yaml"
}
