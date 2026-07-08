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
      PROXMOX_VE_ENDPOINT  = include.env.locals.proxmox_endpoint
      PROXMOX_VE_API_TOKEN = include.env.locals.secrets.proxmox_api_token
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

  # Single control plane, sized up so it can also carry workloads. One etcd
  # member means no quorum/HA: a CP outage stops the API (workloads keep
  # running on the workers) and losing the node requires an etcd snapshot
  # restore, so etcd backups are mandatory. Scaling a *live* 3-member etcd
  # down to 1 must be done one member at a time (destroying two at once loses
  # quorum); on a disposable POC, rebuild instead.
  control_plane_nodes = {
    controlplane-1 = {
      server_type = "cx33"
    }
  }

  worker_nodes = {
    worker-1 = {
      server_type = "cx33"
    }
    worker-2 = {
      server_type = "cx23"
    }
    worker-3 = {
      server_type = "cx23"
    }
    worker-4 = {
      server_type = "cx23"
    }
  }

  kubeconfig_path          = "${get_repo_root()}/.kube/${include.env.locals.cluster_name}.kubeconfig"
  talosconfig_path         = "${get_repo_root()}/.talos/${include.env.locals.cluster_name}.talosconfig"
  bootstrap_manifests_path = "${get_repo_root()}/.kube/${include.env.locals.cluster_name}-bootstrap-manifests.yaml"

  proxmox_node               = include.env.locals.proxmox_node
  proxmox_talos_schematic_id = include.env.locals.proxmox_talos_schematic_id
  proxmox_ssh_private_key    = include.env.locals.secrets.proxmox_ssh_private_key
  proxmox_ssh_password       = include.env.locals.secrets.proxmox_ssh_password

  proxmox_vm_datastore       = "first"
  proxmox_image_datastore    = "talos-store"
  proxmox_snippets_datastore = "talos-store"

  proxmox_workers = {
    proxmox-1 = { vm_id = 9001, ip = "10.0.10.31" }
    proxmox-2 = { vm_id = 9002, ip = "10.0.10.32" }
    proxmox-3 = { vm_id = 9003, ip = "10.0.10.33" }
  }
}
