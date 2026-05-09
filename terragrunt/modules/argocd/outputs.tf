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
