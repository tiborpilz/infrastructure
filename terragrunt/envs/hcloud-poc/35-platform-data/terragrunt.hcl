include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  expose         = true
  merge_strategy = "no_merge"
}

terraform {
  source = "${get_repo_root()}//terragrunt/modules/platform-data"
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

# 20-argocd installs Argo CD (whose Application CRD we use). No outputs
# consumed but order matters at apply time.
dependency "argocd" {
  config_path                             = "../20-argocd"
  skip_outputs                            = true
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
}

inputs = {
  kubernetes_host        = dependency.cluster.outputs.kubernetes_host
  cluster_ca_certificate = dependency.cluster.outputs.cluster_ca_certificate
  client_certificate     = dependency.cluster.outputs.client_certificate
  client_key             = dependency.cluster.outputs.client_key

  kubeconfig_path = "${get_repo_root()}/.kube/${include.env.locals.cluster_name}.kubeconfig"

  hcloud_token = get_env("HCLOUD_TOKEN", "")

  hcloud_csi_values = templatefile(
    "${get_repo_root()}/applications/hcloud-csi/values.yaml.tpl",
    {}
  )

  cnpg_values = templatefile(
    "${get_repo_root()}/applications/cnpg-operator/values.yaml.tpl",
    {}
  )
}
