include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  expose         = true
  merge_strategy = "no_merge"
}

terraform {
  source = "${get_repo_root()}//terragrunt/modules/argocd"
}

# Need both layers: machines for the network ID (CCM uses it), cluster for
# the kubeconfig material.
dependency "machines" {
  config_path = "../00-machines"

  mock_outputs = {
    network_id = "0"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
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

inputs = {
  kubernetes_host        = dependency.cluster.outputs.kubernetes_host
  cluster_ca_certificate = dependency.cluster.outputs.cluster_ca_certificate
  client_certificate     = dependency.cluster.outputs.client_certificate
  client_key             = dependency.cluster.outputs.client_key

  hcloud_token      = get_env("HCLOUD_TOKEN", "")
  hcloud_network_id = dependency.machines.outputs.network_id
}
