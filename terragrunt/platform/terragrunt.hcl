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
    cluster_output                 = "mock-cluster-output"
    kubernetes_host                = "https://203.0.113.1:6443"
    cluster_ca_certificate         = include.env.locals.mock_kubernetes_certificate_pem
    client_certificate             = include.env.locals.mock_kubernetes_certificate_pem
    client_key                     = include.env.locals.mock_kubernetes_key_pem
    network_id                     = "0"
    firewall_id                    = null
    talos_image_id                 = "0"
    worker_machine_config_template = "version: v1alpha1\n# mock-machine-config\n"
  }
  # destroy/state are allowed so the layer can be torn down or state-edited
  # after the cluster layer is already gone (everything in-cluster is dead at
  # that point anyway; only external resources like DNS records remain real).
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan", "destroy", "state"]

  # Shallow-merge mocks over live state so adding a new cluster output doesn't
  # break this layer's parse on stale state. Real outputs always win when
  # present; mocks fill in the gaps until `terragrunt --working-dir
  # terragrunt/cluster apply` refreshes them.
  mock_outputs_merge_strategy_with_state = "shallow"
}

inputs = {
  kubernetes_host        = dependency.cluster.outputs.kubernetes_host
  cluster_ca_certificate = dependency.cluster.outputs.cluster_ca_certificate
  client_certificate     = dependency.cluster.outputs.client_certificate
  client_key             = dependency.cluster.outputs.client_key

  kubeconfig_path      = "${get_repo_root()}/.kube/${include.env.locals.cluster_name}.kubeconfig"
  hcloud_token         = include.env.locals.secrets.hcloud_token
  hcloud_location      = include.env.locals.location
  domain               = include.env.locals.domain
  admin_email          = include.env.locals.acme_email
  cloudflare_api_token = include.env.locals.secrets.cloudflare_api_token

  hcloud_csi_values = templatefile(
    "${get_repo_root()}/applications/hcloud-csi/values.yaml.tpl",
    {}
  )

  cnpg_values = templatefile(
    "${get_repo_root()}/applications/cnpg-operator/values.yaml.tpl",
    {}
  )

  metrics_server_values = templatefile(
    "${get_repo_root()}/applications/metrics-server/values.yaml.tpl",
    {}
  )

  kube_prometheus_stack_values = templatefile(
    "${get_repo_root()}/applications/kube-prometheus-stack/values.yaml.tpl",
    {
      authentik_url        = "https://auth.${include.env.locals.domain}"
      grafana_url          = "https://grafana.${include.env.locals.domain}"
      grafana_hostname     = "grafana.${include.env.locals.domain}"
      storage_class        = "hcloud-volumes"
      oidc_secret_checksum = "tf-managed"
      # JMESPath: any user in platform-admins → Admin, else empty (rejected
      # by Grafana when role_attribute_strict: true).
      role_attribute_path = "contains(groups[*], 'platform-admins') && 'Admin' || ''"
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

  # Cluster-autoscaler: burst pool spec + cluster wiring. Bump pool_max if
  # CI / Woodpecker pipelines hit the ceiling; bump pool_instance_type if a
  # single job needs more than the pool's per-node memory.
  worker_machine_config = dependency.cluster.outputs.worker_machine_config_template

  cluster_autoscaler_values = templatefile(
    "${get_repo_root()}/applications/cluster-autoscaler/values.yaml.tpl",
    {
      cluster_name  = include.env.locals.cluster_name
      pool_location = include.env.locals.location
      # Multi-tier burst pools. `least-waste` (set in values.yaml.tpl) routes
      # pending pods to the smallest pool that fits. Pool names must not
      # contain underscores — the chart's extraArgs renderer splits on `_`
      # to allow duplicate-flag keys (nodes_<tier> → --nodes=...).
      pools = [
        { name = "burst-medium", instance_type = "cpx32", min = 0, max = 3 },
        { name = "burst-large", instance_type = "cpx52", min = 0, max = 2 },
      ]
      hcloud_image_id    = tostring(dependency.cluster.outputs.talos_image_id)
      hcloud_network_id  = tostring(dependency.cluster.outputs.network_id)
      hcloud_firewall_id = try(tostring(dependency.cluster.outputs.firewall_id), "")
      secret_name        = "cluster-autoscaler-hcloud"
    }
  )
}
