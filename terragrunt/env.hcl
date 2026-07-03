locals {
  # Instance identity — single source of truth is config/platform.yaml.
  # Change it via scripts/rebrand (never by hand) so the application layer
  # is rewritten in the same commit.
  platform = yamldecode(file("${get_repo_root()}/config/platform.yaml"))

  secrets = yamldecode(sops_decrypt_file("${get_repo_root()}/terragrunt/secrets.enc.yaml"))

  domain     = local.platform.domain
  repo_url   = local.platform.repo_url
  acme_email = local.platform.acme_email

  env_name     = local.platform.cluster_name
  cluster_name = local.env_name

  bootstrap_admin_email = "admin@${local.domain}"

  # Site facts — describe where this instance runs, not what it is called.
  # Edit these by hand as the deployment site changes.
  location     = "fsn1"
  network_cidr = "10.0.0.0/16"
  subnet_cidr  = "10.0.0.0/24"

  talos_version = "1.13.0"
  arch          = "amd64"

  talos_image_labels = {
    os      = "talos"
    version = local.talos_version
    arch    = local.arch
  }

  proxmox_endpoint           = "https://proxmox.tibor.app:8006"
  proxmox_node               = "proxmox"
  proxmox_talos_schematic_id = "ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515"

  admin_ip_cidrs = []

  argocd_age_key = local.secrets.argocd_age_key
}
