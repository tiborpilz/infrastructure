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

output "talos_cp_endpoints" {
  description = "Public IPv4 addresses of the control-plane Talos endpoints (port 50000). Used by downstream layers that talk directly to the Talos API, e.g., the etcd snapshot CronJob in 37-velero."
  value       = [for n in local.cp_nodes : n.public_ipv4]
}
