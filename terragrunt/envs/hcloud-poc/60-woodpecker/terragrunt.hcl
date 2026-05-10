include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  expose         = true
  merge_strategy = "no_merge"
}

terraform {
  source = "${get_repo_root()}//terragrunt/modules/woodpecker"
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

dependency "forgejo" {
  config_path = "../55-forgejo"

  mock_outputs = {
    forgejo_url       = "https://git.example.com"
    forgejo_namespace = "forgejo"
    ready             = true
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
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

  kubeconfig_path = "${get_repo_root()}/.kube/${include.env.locals.cluster_name}.kubeconfig"

  domain            = include.env.locals.domain
  gateway_namespace = dependency.networking.outputs.gateway_namespace
  gateway_name      = dependency.networking.outputs.gateway_name

  storage_class       = dependency.platform_data.outputs.storage_class
  platform_data_ready = dependency.platform_data.outputs.ready

  forgejo_url       = dependency.forgejo.outputs.forgejo_url
  forgejo_namespace = dependency.forgejo.outputs.forgejo_namespace
  forgejo_ready     = dependency.forgejo.outputs.ready

  woodpecker_admins = local.woodpecker_admins

  woodpecker_values_yaml = templatefile(
    "${get_repo_root()}/terragrunt/modules/woodpecker/templates/values.yaml.tpl",
    {
      agent_data_size      = "1Gi"
      forgejo_url          = dependency.forgejo.outputs.forgejo_url
      pipeline_volume_size = "10G"
      server_data_size     = "10Gi"
      storage_class        = dependency.platform_data.outputs.storage_class
      woodpecker_admins    = join(",", local.woodpecker_admins)
      woodpecker_url       = "https://ci.${include.env.locals.domain}"
    }
  )
}
