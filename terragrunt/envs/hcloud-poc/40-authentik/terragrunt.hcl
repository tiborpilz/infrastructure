include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  expose         = true
  merge_strategy = "no_merge"
}

terraform {
  source = "${get_repo_root()}//terragrunt/modules/authentik"
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

  # Render the four templates here so substitutions happen at the env layer
  # (matches the 30-networking pattern). The module recombines them into the
  # chart's `additionalObjects` since each entry must be a structured object.
  authentik_values_yaml = templatefile(
    "${get_repo_root()}/applications/authentik/values.yaml.tpl",
    {}
  )

  database_yaml = templatefile(
    "${get_repo_root()}/applications/authentik/database.yaml.tpl",
    {
      pg_storage_size = "10Gi"
      storage_class   = dependency.platform_data.outputs.storage_class
    }
  )

  valkey_service_yaml = templatefile(
    "${get_repo_root()}/applications/authentik/valkey-service.yaml.tpl",
    {}
  )

  valkey_statefulset_yaml = templatefile(
    "${get_repo_root()}/applications/authentik/valkey-statefulset.yaml.tpl",
    {
      valkey_image = "valkey/valkey:8"
    }
  )
}
