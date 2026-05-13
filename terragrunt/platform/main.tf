locals {
  argocd_ready        = module.argocd.argocd_ready
  platform_data_ready = module.platform_data.ready
}

module "argocd" {
  source = "./argocd"

  kubernetes_host        = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key

  hcloud_token      = var.hcloud_token
  hcloud_network_id = var.hcloud_network_id

  sops_age_key    = var.sops_age_key
  kubeconfig_path = var.kubeconfig_path

  domain = var.domain
}

module "networking" {
  source = "./networking"

  kubernetes_host        = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key

  argocd_ready         = local.argocd_ready
  domain               = var.domain
  hcloud_location      = var.hcloud_location
  kubeconfig_path      = var.kubeconfig_path
  cloudflare_api_token = var.cloudflare_api_token
  cert_manager_values  = var.cert_manager_values
  external_dns_values  = var.external_dns_values
}

module "smoke_app" {
  source = "./smoke-app"

  kubernetes_host        = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key

  domain            = var.domain
  gateway_namespace = module.networking.gateway_namespace
  gateway_name      = module.networking.gateway_name
}

module "platform_data" {
  source = "./platform-data"

  kubernetes_host        = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key

  argocd_ready    = local.argocd_ready
  kubeconfig_path = var.kubeconfig_path
  hcloud_token    = var.hcloud_token

  hcloud_csi_values = var.hcloud_csi_values
  cnpg_values       = var.cnpg_values
}

module "metrics_server" {
  source = "./metrics-server"

  kubernetes_host        = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key

  argocd_ready    = local.argocd_ready
  kubeconfig_path = var.kubeconfig_path

  metrics_server_values = var.metrics_server_values
}

module "longhorn" {
  source = "./longhorn"

  kubernetes_host        = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key

  argocd_ready    = local.argocd_ready
  kubeconfig_path = var.kubeconfig_path

  longhorn_values = var.longhorn_values
}

module "authentik" {
  source = "./authentik"

  kubernetes_host        = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key

  kubeconfig_path     = var.kubeconfig_path
  domain              = var.domain
  admin_email         = var.admin_email
  gateway_namespace   = module.networking.gateway_namespace
  gateway_name        = module.networking.gateway_name
  storage_class       = module.platform_data.storage_class
  platform_data_ready = local.platform_data_ready

  authentik_values_yaml   = var.authentik_values_yaml
  database_yaml           = var.authentik_database_yaml
  valkey_service_yaml     = var.authentik_valkey_service_yaml
  valkey_statefulset_yaml = var.authentik_valkey_statefulset_yaml
}

module "observability" {
  source = "./observability"

  kubernetes_host        = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key

  kubeconfig_path     = var.kubeconfig_path
  domain              = var.domain
  argocd_ready        = local.argocd_ready
  platform_data_ready = local.platform_data_ready
  authentik_url       = module.authentik.authentik_url
  authentik_token     = module.authentik.bootstrap_admin_token
  authentik_ready     = module.authentik.ready
  storage_class       = module.platform_data.storage_class
  gateway_namespace   = module.networking.gateway_namespace
  gateway_name        = module.networking.gateway_name

  kube_prometheus_stack_values = var.kube_prometheus_stack_values
}
