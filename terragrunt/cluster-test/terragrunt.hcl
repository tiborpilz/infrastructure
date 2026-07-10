# Disposable test cluster: the full cluster stack (Talos + Cilium + ArgoCD +
# cert-manager + external-dns) on a single small Hetzner VM. Own state, own
# network and floating IP, DNS under test.<domain> — apply and destroy at
# will without touching the main cluster.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  expose         = true
  merge_strategy = "no_merge"
}

terraform {
  source = "../cluster"

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
  env_name           = "hcloud-test"
  cluster_name       = "hcloud-test"
  location           = include.env.locals.location
  network_cidr       = include.env.locals.network_cidr
  subnet_cidr        = include.env.locals.subnet_cidr
  talos_image_labels = include.env.locals.talos_image_labels
  firewall_admin_ips = include.env.locals.admin_ip_cidrs
  talos_version      = include.env.locals.talos_version

  # Records live under test.<domain> inside the parent zone; the distinct
  # external-dns owner id keeps this cluster off the main cluster's records.
  domain                      = "test.${include.env.locals.domain}"
  dns_zone                    = include.env.locals.domain
  external_dns_txt_owner_id   = "hcloud-test"
  external_dns_domain_filters = ["test.${include.env.locals.domain}"]

  admin_email          = include.env.locals.acme_email
  cloudflare_api_token = include.env.locals.secrets.cloudflare_api_token
  hcloud_token         = include.env.locals.secrets.hcloud_token
  authentik_secret_key = include.env.locals.secrets.authentik_secret_key
  argocd_age_key       = include.env.locals.argocd_age_key

  # One VM carries the whole cluster: a single control plane with workload
  # scheduling on (the talos module's default). hcloud server names are
  # unique per project, hence the test- prefix.
  control_plane_nodes = {
    test-controlplane-1 = {
      server_type = "cx33"
    }
  }
  worker_nodes    = {}
  proxmox_workers = {}

  kubeconfig_path          = "${get_repo_root()}/.kube/hcloud-test.kubeconfig"
  talosconfig_path         = "${get_repo_root()}/.talos/hcloud-test.talosconfig"
  bootstrap_manifests_path = "${get_repo_root()}/.kube/hcloud-test-bootstrap-manifests.yaml"
}
