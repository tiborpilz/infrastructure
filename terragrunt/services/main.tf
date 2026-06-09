locals {
  authentik_config_ready = length(module.authentik_config.managed_groups) >= 0
  forgejo_ready          = module.forgejo.ready
}

module "authentik_config" {
  source = "./authentik-config"

  authentik_url   = var.authentik_url
  authentik_token = var.authentik_token
  authentik_ready = var.authentik_ready

  managed_users              = var.managed_users
  managed_user_passwords     = var.managed_user_passwords
  platform_admin_groups      = var.platform_admin_groups
  authentik_superuser_groups = var.authentik_superuser_groups
}

module "argocd_oidc" {
  source = "./argocd-oidc"

  authentik_url   = var.authentik_url
  authentik_token = var.authentik_token
  authentik_ready = var.authentik_ready

  argocd_url                = var.argocd_url
  argocd_oidc_client_id     = var.argocd_oidc_client_id
  argocd_oidc_client_secret = var.argocd_oidc_client_secret
  argocd_oidc_redirect_uri  = var.argocd_oidc_redirect_uri
}

module "forgejo" {
  source = "./forgejo"

  kubernetes_host        = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key

  kubeconfig_path        = var.kubeconfig_path
  domain                 = var.domain
  admin_email            = var.admin_email
  gateway_namespace      = var.gateway_namespace
  gateway_name           = var.gateway_name
  storage_class          = var.storage_class
  platform_data_ready    = var.platform_data_ready
  authentik_url          = var.authentik_url
  authentik_token        = var.authentik_token
  authentik_ready        = var.authentik_ready
  authentik_config_ready = local.authentik_config_ready
  forgejo_values_yaml    = var.forgejo_values_yaml
  database_yaml          = var.forgejo_database_yaml
}

module "woodpecker" {
  source = "./woodpecker"

  kubernetes_host        = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key

  kubeconfig_path        = var.kubeconfig_path
  domain                 = var.domain
  gateway_namespace      = var.gateway_namespace
  gateway_name           = var.gateway_name
  storage_class          = var.storage_class
  platform_data_ready    = var.platform_data_ready
  forgejo_url            = module.forgejo.forgejo_url
  forgejo_namespace      = module.forgejo.forgejo_namespace
  forgejo_ready          = local.forgejo_ready
  woodpecker_admins      = var.woodpecker_admins
  woodpecker_values_yaml = var.woodpecker_values_yaml
}

module "omni" {
  source = "./omni"

  kubernetes_host        = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key

  kubeconfig_path        = var.kubeconfig_path
  domain                 = var.domain
  gateway_namespace      = var.gateway_namespace
  gateway_name           = var.gateway_name
  storage_class          = var.storage_class
  platform_data_ready    = var.platform_data_ready
  authentik_url          = var.authentik_url
  authentik_token        = var.authentik_token
  authentik_ready        = var.authentik_ready
  authentik_config_ready = local.authentik_config_ready

  omni_etcd_gpg_key             = var.omni_etcd_gpg_key
  omni_admin_emails             = var.omni_admin_emails
  siderolink_wireguard_endpoint = var.omni_siderolink_wireguard_endpoint
  omni_values_yaml              = var.omni_values_yaml
}

module "hubble_proxy" {
  source = "./oauth2-proxy"

  name         = "hubble"
  display_name = "Hubble UI"

  upstream_service_namespace = "kube-system"
  upstream_service_name      = "hubble-ui"
  upstream_service_port      = 80

  admin_groups = ["platform-admins"]

  kubernetes_host        = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key
  kubeconfig_path        = var.kubeconfig_path

  authentik_url          = var.authentik_url
  authentik_token        = var.authentik_token
  authentik_ready        = var.authentik_ready
  authentik_config_ready = local.authentik_config_ready

  domain            = var.domain
  gateway_namespace = var.gateway_namespace
  gateway_name      = var.gateway_name
}

module "tekton" {
  source = "./tekton"

  kubernetes_host        = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key

  kubeconfig_path     = var.kubeconfig_path
  platform_data_ready = var.platform_data_ready
}

module "tangled" {
  source = "./tangled"

  kubernetes_host        = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key

  kubeconfig_path     = var.kubeconfig_path
  domain              = var.domain
  gateway_namespace   = var.gateway_namespace
  gateway_name        = var.gateway_name
  storage_class       = var.storage_class
  platform_data_ready = var.platform_data_ready

  owner_did      = var.tangled_owner_did
  knot_image     = var.tangled_knot_image
  knot_image_tag = var.tangled_knot_image_tag
}

module "tekton_dashboard_proxy" {
  source = "./oauth2-proxy"

  name         = "tekton"
  display_name = "Tekton Dashboard"

  upstream_service_namespace = module.tekton.components_namespace
  upstream_service_name      = module.tekton.dashboard_service_name
  upstream_service_port      = module.tekton.dashboard_service_port

  admin_groups = ["platform-admins"]

  kubernetes_host        = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key
  kubeconfig_path        = var.kubeconfig_path

  authentik_url          = var.authentik_url
  authentik_token        = var.authentik_token
  authentik_ready        = var.authentik_ready
  authentik_config_ready = local.authentik_config_ready

  domain            = var.domain
  gateway_namespace = var.gateway_namespace
  gateway_name      = var.gateway_name
}
