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

  # Cluster-autoscaler: burst pool spec + cluster wiring. Bump pool_max if
  # CI / Woodpecker pipelines hit the ceiling; bump pool_instance_type if a
  # single job needs more than the pool's per-node memory.
  worker_machine_config = dependency.cluster.outputs.worker_machine_config_template

  argocd_oidc_client_secret = dependency.cluster.outputs.argocd_oidc_client_secret
  authentik_bootstrap_token = dependency.cluster.outputs.authentik_bootstrap_token

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
