include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  expose         = true
  merge_strategy = "no_merge"
}

terraform {
  source = "${get_repo_root()}//terragrunt/modules/forgejo"
}

dependency "cluster" {
  config_path = "../10-cluster"

  mock_outputs = {
    kubernetes_host        = "https://203.0.113.1:6443"
    cluster_ca_certificate = "mock-ca"
    client_certificate     = "mock-cert"
    client_key             = "mock-key"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "argocd" {
  config_path                             = "../20-argocd"
  skip_outputs                            = true
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "networking" {
  config_path = "../30-networking"

  mock_outputs = {
    gateway_namespace = "gateway-system"
    gateway_name      = "public"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "platform_data" {
  config_path = "../35-platform-data"

  mock_outputs = {
    storage_class = "hcloud-volumes"
    ready         = true
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "authentik" {
  config_path = "../40-authentik"

  mock_outputs = {
    authentik_url         = "https://auth.example.com"
    bootstrap_admin_token = "mock-token"
    ready                 = true
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

dependency "authentik_config" {
  config_path                             = "../45-authentik-config"
  skip_outputs                            = true
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

inputs = {
  kubernetes_host        = dependency.cluster.outputs.kubernetes_host
  cluster_ca_certificate = dependency.cluster.outputs.cluster_ca_certificate
  client_certificate     = dependency.cluster.outputs.client_certificate
  client_key             = dependency.cluster.outputs.client_key

  kubeconfig_path = "${get_repo_root()}/.kube/${include.env.locals.cluster_name}.kubeconfig"

  domain            = include.env.locals.domain
  admin_email       = include.env.locals.acme_email
  gateway_namespace = dependency.networking.outputs.gateway_namespace
  gateway_name      = dependency.networking.outputs.gateway_name

  storage_class       = dependency.platform_data.outputs.storage_class
  platform_data_ready = dependency.platform_data.outputs.ready

  authentik_url   = dependency.authentik.outputs.authentik_url
  authentik_token = dependency.authentik.outputs.bootstrap_admin_token
  authentik_ready = dependency.authentik.outputs.ready

  forgejo_values_yaml = templatefile(
    "${get_repo_root()}/terragrunt/modules/forgejo/templates/values.yaml.tpl",
    {
      admin_email           = include.env.locals.acme_email
      admin_secret_checksum = "tf-managed"
      forgejo_data_size     = "20Gi"
      forgejo_url           = "https://git.${include.env.locals.domain}"
      gateway_name          = dependency.networking.outputs.gateway_name
      gateway_namespace     = dependency.networking.outputs.gateway_namespace
      hostname              = "git.${include.env.locals.domain}"
      oidc_discovery_url    = "${dependency.authentik.outputs.authentik_url}/application/o/forgejo/.well-known/openid-configuration"
      oidc_secret_checksum  = "tf-managed"
      pg_storage_size       = "10Gi"
      storage_class         = dependency.platform_data.outputs.storage_class
    }
  )

  database_yaml = templatefile(
    "${get_repo_root()}/terragrunt/modules/forgejo/templates/database.yaml.tpl",
    {
      pg_storage_size = "10Gi"
      storage_class   = dependency.platform_data.outputs.storage_class
    }
  )
}
