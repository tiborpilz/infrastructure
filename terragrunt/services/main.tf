locals {
  authentik_config_ready = length(module.authentik_config.managed_groups) >= 0
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
  forgejo_url            = "https://git.${var.domain}"
  forgejo_namespace      = "forgejo"
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


module "tekton" {
  source = "./tekton"

  kubernetes_host        = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key

  kubeconfig_path     = var.kubeconfig_path
  platform_data_ready = var.platform_data_ready
}

module "pds" {
  source = "./pds"

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

  handles = var.pds_handles
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

  knot_image                  = var.tangled_knot_image
  knot_image_tag              = var.tangled_knot_image_tag
  did_subdomain               = var.tangled_did_subdomain
  owner_handle                = var.tangled_owner_handle
  owner_signing_key_multibase = var.tangled_owner_signing_key_multibase
  owner_pds_endpoint          = var.tangled_owner_pds_endpoint
}

