resource "terraform_data" "argocd_ready" {
  triggers_replace = { kubeconfig = var.kubeconfig_path }

  provisioner "local-exec" {
    environment = { KUBECONFIG = var.kubeconfig_path }
    command     = "kubectl rollout status deployment/argocd-server -n argocd --timeout=180s"
  }
}

resource "terraform_data" "authentik_ready" {
  triggers_replace = { kubeconfig = var.kubeconfig_path }

  provisioner "local-exec" {
    environment = { KUBECONFIG = var.kubeconfig_path }
    command     = "kubectl rollout status deployment/authentik-server -n authentik --timeout=300s"
  }

  depends_on = [terraform_data.argocd_ready]
}

locals {
  platform_data_ready = module.platform_data.ready
  argocd_ready        = terraform_data.argocd_ready.id
  authentik_ready     = terraform_data.authentik_ready.id
}

module "networking" {
  source = "./networking"

  kubernetes_host        = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key

  domain           = var.domain
  hcloud_location  = var.hcloud_location
  kubeconfig_path  = var.kubeconfig_path
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

module "cluster_autoscaler" {
  source = "./cluster-autoscaler"

  kubernetes_host        = var.kubernetes_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key

  argocd_ready    = local.argocd_ready
  kubeconfig_path = var.kubeconfig_path

  hcloud_token              = var.hcloud_token
  worker_machine_config     = var.worker_machine_config
  cluster_autoscaler_values = var.cluster_autoscaler_values
}
