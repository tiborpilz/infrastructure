output "nodes" {
  description = "Generic node inventory."
  value       = module.hcloud_server.nodes
}

output "network_id" {
  description = "Hetzner Cloud network ID."
  value       = module.hcloud_network.network_id
}

output "subnet_id" {
  description = "Hetzner Cloud subnet ID."
  value       = module.hcloud_network.subnet_id
}

output "firewall_ids" {
  description = "Cluster firewall IDs (empty list if firewall is disabled)."
  value       = module.hcloud_network.firewall_ids
}

output "location" {
  description = "Hetzner Cloud location."
  value       = module.hcloud_server.location
}

output "kubeconfig" {
  description = "kubeconfig for kubectl."
  value       = module.talos.kubeconfig
  sensitive   = true
}

output "talosconfig" {
  description = "talosctl client configuration."
  value       = module.talos.talosconfig
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Cluster API endpoint."
  value       = module.talos.cluster_endpoint
}

output "cluster_name" {
  description = "Cluster name."
  value       = module.talos.cluster_name
}

output "kubernetes_host" {
  description = "Kubernetes API server URL."
  value       = module.talos.kubernetes_host
}

output "cluster_ca_certificate" {
  description = "Kubernetes cluster CA certificate."
  value       = module.talos.cluster_ca_certificate
  sensitive   = true
}

output "client_certificate" {
  description = "Kubernetes client certificate."
  value       = module.talos.client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Kubernetes client key."
  value       = module.talos.client_key
  sensitive   = true
}

output "talos_version" {
  description = "Talos version."
  value       = module.talos.talos_version
}

output "talos_control_plane_endpoints" {
  description = "Public IPv4 addresses of Talos control-plane endpoints."
  value       = module.talos.talos_control_plane_endpoints
}

output "worker_machine_config_template" {
  description = "Generic worker MachineConfig (Talos YAML) for cluster-autoscaler to inject as Hetzner user-data."
  value       = module.talos.worker_machine_config_template
  sensitive   = true
}

output "talos_image_id" {
  description = "Numeric Hetzner snapshot ID of the Talos image currently in use."
  value       = module.hcloud_server.talos_image_id
}


output "node_fqdns" {
  description = "Map of node name to FQDN under the configured subdomain (e.g., controlplane-1 → controlplane-1.kube.tibor.sh)."
  value       = module.dns.node_fqdns
}

output "control_plane_machine_config" {
  value     = module.talos.control_plane_machine_config
  sensitive = true
}
