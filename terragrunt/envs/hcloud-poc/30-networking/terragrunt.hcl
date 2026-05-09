include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  expose         = true
  merge_strategy = "no_merge"
}

terraform {
  source = "${get_repo_root()}//terragrunt/modules/networking"
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

# 20-argocd installs Argo CD (whose CRDs we use for Application resources).
# No outputs consumed but the order matters at apply time.
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

  domain               = include.env.locals.domain
  cloudflare_api_token = get_env("CLOUDFLARE_API_TOKEN", "")

  # Helm values are rendered here so domain + email substitutions happen
  # at the env layer, not buried in the module.
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
}
