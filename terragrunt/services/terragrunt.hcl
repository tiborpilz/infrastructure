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
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
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
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
}

locals {
  woodpecker_admins = [
    for username, user in include.env.locals.managed_users : username
    if try(user.admin, false)
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

  managed_users              = include.env.locals.managed_users
  managed_user_passwords     = include.env.locals.managed_user_passwords
  platform_admin_groups      = include.env.locals.platform_admin_groups
  authentik_superuser_groups = include.env.locals.authentik_superuser_groups
  woodpecker_admins          = local.woodpecker_admins

  forgejo_values_yaml = templatefile(
    "${get_terragrunt_dir()}/forgejo/templates/values.yaml.tpl",
    {
      admin_email           = include.env.locals.acme_email
      admin_secret_checksum = "tf-managed"
      forgejo_data_size     = "20Gi"
      forgejo_url           = "https://git.${include.env.locals.domain}"
      gateway_name          = dependency.platform.outputs.gateway_name
      gateway_namespace     = dependency.platform.outputs.gateway_namespace
      hostname              = "git.${include.env.locals.domain}"
      oidc_discovery_url    = "${dependency.platform.outputs.authentik_url}/application/o/forgejo/.well-known/openid-configuration"
      oidc_secret_checksum  = "tf-managed"
      pg_storage_size       = "10Gi"
      storage_class         = dependency.platform.outputs.storage_class
    }
  )

  forgejo_database_yaml = templatefile(
    "${get_terragrunt_dir()}/forgejo/templates/database.yaml.tpl",
    {
      pg_storage_size = "10Gi"
      storage_class   = dependency.platform.outputs.storage_class
    }
  )

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
}
