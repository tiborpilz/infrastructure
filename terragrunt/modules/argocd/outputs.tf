output "argocd_namespace" {
  description = "Namespace where Argo CD is installed."
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_chart_version" {
  description = "Argo CD Helm chart version that was applied."
  value       = var.argocd_chart_version
}

output "cilium_chart_version" {
  description = "Cilium Helm chart version that was applied."
  value       = var.cilium_chart_version
}

output "hcloud_ccm_chart_version" {
  description = "hcloud-cloud-controller-manager Helm chart version that was applied."
  value       = var.hcloud_ccm_chart_version
}

output "argocd_url" {
  description = "Public URL of the Argo CD UI."
  value       = local.argocd_url
}

output "argocd_oidc_client_id" {
  description = "OIDC client_id Argo CD uses against authentik. Always `argocd`."
  value       = "argocd"
}

output "argocd_oidc_client_secret" {
  description = "OIDC client_secret matching what's baked into the Argo CD chart. The downstream 50-argocd-oidc layer creates the matching authentik_provider_oauth2 with this value."
  value       = random_password.argocd_oidc_client_secret.result
  sensitive   = true
}

output "argocd_oidc_redirect_uri" {
  description = "Redirect URI authentik must whitelist for the OIDC handshake."
  value       = local.argocd_oidc_redirect_uri
}
