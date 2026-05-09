locals {
  env_name     = "hcloud-poc"
  cluster_name = local.env_name
  location     = "hel1"
  network_cidr = "10.0.0.0/16"
  subnet_cidr  = "10.0.0.0/24"

  # Talos version + arch. Single source of truth across machines, cluster,
  # and the upload script.
  # Bump in lockstep with setup/upload-talos-image.sh.
  # If CX43 in hel1 turns out to be ARM, change arch to "arm64" and re-run the upload script.
  talos_version = "1.13.0"
  arch          = "amd64"

  talos_image_labels = {
    os      = "talos"
    version = local.talos_version
    arch    = local.arch
  }

  # Empty list = no firewall created; Talos API (50000) and k8s API (6443)
  # are exposed publicly. Both are mTLS-protected so this is safe-but-noisy.
  # Tighten via VPN/bastion later, then list the gateway CIDR(s) here.
  admin_ip_cidrs = []

  # Networking / DNS / TLS
  domain     = "tiborpilz.dev"
  acme_email = "tibor@pilz.berlin"

  # Declarative Authentik users. Passwords can be supplied from SOPS
  # later via managed_user_passwords; omitted users receive stable
  # Terraform-generated random passwords.
  platform_admin_groups = [
    "platform-admins",
    "kubernetes-admins",
  ]

  # Keep Authentik superuser separate from platform admin rights. Add
  # "platform-admins" here if bootstrap admins should administer Authentik
  # itself, not just downstream apps such as Argo CD and Kubernetes.
  authentik_superuser_groups = [
    "authentik-superusers",
  ]

  managed_users = {
    example = {
      name   = "Tibor"
      email  = "tibor@pilz.berlin"
      admin  = true
      groups = ["platform-admins"]
    }

    example = {
      name   = "Tine"
      email  = "tine@olynet.de"
      admin  = true
      groups = []
    }

    # example = {
    #   name   = "Example Admin"
    #   email  = "admin@example.com"
    #   admin  = true
    #   groups = ["forgejo-users"]
    # }
  }

  managed_user_passwords = {}
}
