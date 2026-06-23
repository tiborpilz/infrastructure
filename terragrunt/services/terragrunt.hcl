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

dependency "cluster" {
  config_path = "../cluster"

  mock_outputs = {
    kubernetes_host        = "https://203.0.113.1:6443"
    cluster_ca_certificate = include.env.locals.mock_kubernetes_certificate_pem
    client_certificate     = include.env.locals.mock_kubernetes_certificate_pem
    client_key             = include.env.locals.mock_kubernetes_key_pem
    nodes = {
      control_plane = {}
      workers = {
        "worker-1" = {
          name         = "worker-1"
          ipv4         = "10.0.0.20"
          public_ipv4  = "203.0.113.10"
          install_disk = "/dev/sda"
          arch         = "amd64"
          provider_id  = "hcloud://0"
        }
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan", "destroy", "state"]
}

dependency "platform" {
  config_path = "../platform"

  mock_outputs = {
    argocd_url                = "https://argocd.example.com"
    argocd_oidc_client_id     = "argocd"
    argocd_oidc_client_secret = "mock"
    argocd_oidc_redirect_uri  = "https://argocd.example.com/auth/callback"
    gateway_namespace         = "gateway-system"
    gateway_name              = "public"
    storage_class             = "hcloud-volumes"
    platform_data_ready       = true
    authentik_url             = "https://auth.example.com"
    authentik_token           = "mock-token"
    authentik_ready           = true
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan", "destroy", "state"]
}

locals {
  woodpecker_admins = [
    for username, user in include.env.locals.managed_users : username
    if try(user.admin, false)
  ]

  # All admin emails from managed_users — every one of them becomes an Omni
  # initial admin (only meaningful on the FIRST Omni boot; subsequent users
  # must be added via the Omni UI or omnictl). Falls back to the ACME email
  # if no admins are declared.
  omni_admin_emails = length([
    for _, user in include.env.locals.managed_users : user.email
    if try(user.admin, false)
    ]) > 0 ? [
    for _, user in include.env.locals.managed_users : user.email
    if try(user.admin, false)
    ] : [
    include.env.locals.acme_email,
  ]
}

inputs = {
  kubernetes_host        = dependency.cluster.outputs.kubernetes_host
  cluster_ca_certificate = dependency.cluster.outputs.cluster_ca_certificate
  client_certificate     = dependency.cluster.outputs.client_certificate
  client_key             = dependency.cluster.outputs.client_key
  kubeconfig_path        = "${get_repo_root()}/.kube/${include.env.locals.cluster_name}.kubeconfig"

  domain            = include.env.locals.domain
  admin_email       = include.env.locals.acme_email
  gateway_namespace = dependency.platform.outputs.gateway_namespace
  gateway_name      = dependency.platform.outputs.gateway_name
  storage_class     = dependency.platform.outputs.storage_class

  platform_data_ready = dependency.platform.outputs.platform_data_ready
  authentik_url       = dependency.platform.outputs.authentik_url
  authentik_token     = dependency.platform.outputs.authentik_token
  authentik_ready     = dependency.platform.outputs.authentik_ready

  argocd_url                = dependency.platform.outputs.argocd_url
  argocd_oidc_client_id     = dependency.platform.outputs.argocd_oidc_client_id
  argocd_oidc_client_secret = dependency.platform.outputs.argocd_oidc_client_secret
  argocd_oidc_redirect_uri  = dependency.platform.outputs.argocd_oidc_redirect_uri

  woodpecker_admins = local.woodpecker_admins

  woodpecker_values_yaml = templatefile(
    "${get_terragrunt_dir()}/woodpecker/templates/values.yaml.tpl",
    {
      agent_data_size      = "1Gi"
      forgejo_url          = "https://git.${include.env.locals.domain}"
      pipeline_volume_size = "10G"
      server_data_size     = "10Gi"
      storage_class        = dependency.platform.outputs.storage_class
      woodpecker_admins    = join(",", local.woodpecker_admins)
      woodpecker_url       = "https://ci.${include.env.locals.domain}"
    }
  )

  omni_etcd_gpg_key = try(include.env.locals.secrets.omni_etcd_gpg_key, "")

  pds_handles = try(include.env.locals.pds_handles, [])

  omni_admin_emails = local.omni_admin_emails
  # SideroLink WireGuard advertisedEndpoint must be IP:PORT (hostnames are not
  # supported by the WireGuard config). 30180 is the chart's default NodePort.
  omni_siderolink_wireguard_endpoint = (
    length(dependency.cluster.outputs.nodes.workers) > 0
    ? "${values(dependency.cluster.outputs.nodes.workers)[0].public_ipv4}:30180"
    : ""
  )
  omni_values_yaml = templatefile(
    "${get_terragrunt_dir()}/omni/templates/values.yaml.tpl",
    {
      account_name        = "${include.env.locals.cluster_name}-omni"
      storage_size        = "20Gi"
      storage_class       = dependency.platform.outputs.storage_class
      omni_hostname       = "omni.${include.env.locals.domain}"
      k8s_proxy_hostname  = "omni-k8s.${include.env.locals.domain}"
      siderolink_hostname = "omni-siderolink.${include.env.locals.domain}"
      gateway_name        = dependency.platform.outputs.gateway_name
      gateway_namespace   = dependency.platform.outputs.gateway_namespace
      domain              = include.env.locals.domain
    }
  )
}
