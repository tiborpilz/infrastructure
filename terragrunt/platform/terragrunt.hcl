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
    network_id             = "0"
    talosconfig            = "mock-talosconfig"
    talos_cp_endpoints     = ["203.0.113.1"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
}

inputs = {
  kubernetes_host        = dependency.cluster.outputs.kubernetes_host
  cluster_ca_certificate = dependency.cluster.outputs.cluster_ca_certificate
  client_certificate     = dependency.cluster.outputs.client_certificate
  client_key             = dependency.cluster.outputs.client_key

  kubeconfig_path      = "${get_repo_root()}/.kube/${include.env.locals.cluster_name}.kubeconfig"
  talosconfig_raw      = dependency.cluster.outputs.talosconfig
  talos_cp_endpoints   = dependency.cluster.outputs.talos_cp_endpoints
  hcloud_token         = get_env("HCLOUD_TOKEN", "")
  hcloud_network_id    = dependency.cluster.outputs.network_id
  domain               = include.env.locals.domain
  admin_email          = include.env.locals.acme_email
  cloudflare_api_token = get_env("CLOUDFLARE_API_TOKEN", "")

  hcloud_object_storage_region = include.env.locals.location
  hcloud_s3_access_key         = get_env("HCLOUD_S3_ACCESS_KEY", "")
  hcloud_s3_secret_key         = get_env("HCLOUD_S3_SECRET_KEY", "")
  bucket_name                  = "backups-${include.env.locals.env_name}"

  cert_manager_values = templatefile(
    "${get_repo_root()}/applications/cert-manager/values.yaml.tpl",
    {
      domain = include.env.locals.domain
      email  = include.env.locals.acme_email
    }
  )

  external_dns_values = templatefile(
    "${get_repo_root()}/applications/external-dns/values.yaml.tpl",
    {
      domain = include.env.locals.domain
    }
  )

  hcloud_csi_values = templatefile(
    "${get_repo_root()}/applications/hcloud-csi/values.yaml.tpl",
    {}
  )

  cnpg_values = templatefile(
    "${get_repo_root()}/applications/cnpg-operator/values.yaml.tpl",
    {}
  )

  velero_values = templatefile(
    "${get_repo_root()}/applications/velero/values.yaml.tpl",
    {
      bucket_name = "backups-${include.env.locals.env_name}"
      region      = include.env.locals.location
    }
  )

  authentik_values_yaml = templatefile(
    "${get_repo_root()}/applications/authentik/values.yaml.tpl",
    {}
  )

  authentik_database_yaml = templatefile(
    "${get_repo_root()}/applications/authentik/database.yaml.tpl",
    {
      pg_storage_size = "10Gi"
      storage_class   = "hcloud-volumes"
    }
  )

  authentik_valkey_service_yaml = templatefile(
    "${get_repo_root()}/applications/authentik/valkey-service.yaml.tpl",
    {}
  )

  authentik_valkey_statefulset_yaml = templatefile(
    "${get_repo_root()}/applications/authentik/valkey-statefulset.yaml.tpl",
    {
      valkey_image = "valkey/valkey:8"
    }
  )
}
