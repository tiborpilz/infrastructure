output "kubeconfig" {
  description = "kubeconfig for kubectl. Sensitive."
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "talosconfig" {
  description = "talosconfig for talosctl. Sensitive."
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Cluster API endpoint URL."
  value       = local.effective_endpoint
}

output "cluster_name" {
  description = "Cluster name."
  value       = var.cluster_name
}

# Parsed kubeconfig fields — convenient for downstream Terraform providers
# (kubernetes, helm) that take host + ca + client cert/key directly.
#
# Talos returns these base64-encoded (matching kubeconfig YAML format);
# we decode here so consumers get raw PEM and don't each need a base64decode().

output "kubernetes_host" {
  description = "Kubernetes API server host URL (from kubeconfig)."
  value       = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
}

output "cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate (PEM, decoded)."
  value       = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
}

output "client_certificate" {
  description = "Kubernetes client certificate (PEM, decoded)."
  value       = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
}

output "client_key" {
  description = "Kubernetes client key (PEM, decoded). Sensitive."
  value       = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
  sensitive   = true
}

output "talos_version" {
  description = "Talos version applied to the cluster."
  value       = var.talos_version
}

output "talos_control_plane_endpoints" {
  description = "Public IPv4 addresses of the control-plane Talos endpoints (port 50000). Used by downstream layers that talk directly to the Talos API."
  value       = [for n in local.control_plane_nodes : n.public_ipv4]
}

output "worker_machine_config_template" {
  description = "Generic worker MachineConfig for cluster-autoscaler to inject as Hetzner user-data. Sensitive — contains cluster bootstrap material."
  value       = data.talos_machine_configuration.worker_template.machine_configuration
  sensitive   = true
}

output "control_plane_machine_config" {
  value     = { for k, c in data.talos_machine_configuration.control_plane : k => c.machine_configuration }
  sensitive = true
}

output "bootstrap_manifests_yaml" {
  description = "All bootstrap inline manifests as a multi-document YAML string."
  value       = module.bootstrap.rendered_yaml
  sensitive   = true
}

output "authentik_bootstrap_token" {
  description = "Authentik API bootstrap token (AUTHENTIK_BOOTSTRAP_TOKEN). Used by the services layer to talk to the Authentik API."
  value       = random_password.authentik_bootstrap_token.result
  sensitive   = true
}

output "argocd_oidc_client_secret" {
  description = "ArgoCD OIDC client secret. Stored in argocd/argocd-oidc K8s secret; Authentik provider must use the same value."
  value       = random_password.argocd_oidc_client_secret.result
  sensitive   = true
}
