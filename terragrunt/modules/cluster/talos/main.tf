locals {
  cp_nodes      = var.nodes.control_plane
  worker_nodes  = var.nodes.workers
  first_cp_key  = sort(keys(local.cp_nodes))[0]
  first_cp_node = local.cp_nodes[local.first_cp_key]

  effective_endpoint = coalesce(
    var.cluster_endpoint,
    "https://${local.first_cp_node.public_ipv4}:6443",
  )

  # Cluster-wide config patch.
  # - cni: none — Cilium will be installed via Argo in 30-networking
  # - proxy: disabled — Cilium replaces kube-proxy
  # - externalCloudProvider: enabled — kubelet uses cloud-provider=external;
  #   Hetzner CCM will be installed via Argo in 30-networking
  base_patch = yamlencode({
    cluster = {
      allowSchedulingOnControlPlanes = var.allow_scheduling_on_control_planes
      network = {
        cni            = { name = "none" }
        podSubnets     = [var.pod_cidr]
        serviceSubnets = [var.service_cidr]
        dnsDomain      = var.dns_domain
      }
      proxy = { disabled = true }
      externalCloudProvider = {
        enabled = true
      }
    }
  })
}

# Wait for Talos maintenance API (TCP 50000) on each control-plane public IP
# before attempting to apply config. Uses bash's built-in /dev/tcp so no
# external tool is required.
resource "terraform_data" "wait_for_maintenance" {
  for_each = local.cp_nodes

  triggers_replace = {
    public_ipv4 = each.value.public_ipv4
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      for i in $(seq 1 60); do
        if (echo > /dev/tcp/${each.value.public_ipv4}/50000) 2>/dev/null; then
          echo "Talos maintenance API reachable on ${each.value.public_ipv4} (${each.key})"
          exit 0
        fi
        echo "waiting for Talos API on ${each.value.public_ipv4} (attempt $i/60)..."
        sleep 5
      done
      echo "Talos API on ${each.value.public_ipv4} never came up after 5 minutes" >&2
      exit 1
    EOT
  }
}

# Cluster-wide secrets: cluster CA, etcd CA, machine CA, k8s CA, etc.
resource "talos_machine_secrets" "this" {
  talos_version = "v${var.talos_version}"
}

# Per-CP-node machine config (control-plane role).
data "talos_machine_configuration" "control_plane" {
  for_each = local.cp_nodes

  cluster_name       = var.cluster_name
  cluster_endpoint   = local.effective_endpoint
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = "v${var.talos_version}"
  kubernetes_version = var.kubernetes_version

  config_patches = [
    local.base_patch,
    yamlencode({
      machine = {
        install = { disk = each.value.install_disk }
      }
    }),
  ]
}

# Apply the config to each CP node. The provider uses --insecure mode
# automatically when the node has no client cert (i.e., maintenance mode).
resource "talos_machine_configuration_apply" "control_plane" {
  for_each = local.cp_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane[each.key].machine_configuration
  node                        = each.value.public_ipv4

  depends_on = [terraform_data.wait_for_maintenance]
}

# ---------------------------------------------------------------------------
# Worker nodes: wait for maintenance API, render config, apply.
# Workers don't bootstrap etcd — they join via the same cluster_endpoint as
# CP nodes and trust the cluster CA from talos_machine_secrets.
# ---------------------------------------------------------------------------

resource "terraform_data" "wait_for_maintenance_worker" {
  for_each = local.worker_nodes

  triggers_replace = {
    public_ipv4 = each.value.public_ipv4
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      for i in $(seq 1 60); do
        if (echo > /dev/tcp/${each.value.public_ipv4}/50000) 2>/dev/null; then
          echo "Talos maintenance API reachable on ${each.value.public_ipv4} (${each.key})"
          exit 0
        fi
        echo "waiting for Talos API on ${each.value.public_ipv4} (attempt $i/60)..."
        sleep 5
      done
      echo "Talos API on ${each.value.public_ipv4} never came up after 5 minutes" >&2
      exit 1
    EOT
  }
}

data "talos_machine_configuration" "worker" {
  for_each = local.worker_nodes

  cluster_name       = var.cluster_name
  cluster_endpoint   = local.effective_endpoint
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = "v${var.talos_version}"
  kubernetes_version = var.kubernetes_version

  config_patches = [
    local.base_patch,
    yamlencode({
      machine = {
        install = { disk = each.value.install_disk }
      }
    }),
  ]
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = local.worker_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration
  node                        = each.value.public_ipv4

  depends_on = [
    terraform_data.wait_for_maintenance_worker,
    # Workers join AFTER the cluster is bootstrapped, otherwise they have
    # no apiserver to talk to.
    talos_machine_bootstrap.this,
  ]
}

# Bootstrap etcd on the first CP node. Idempotent — errors gracefully if
# already bootstrapped.
resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_cp_node.public_ipv4
  endpoint             = local.first_cp_node.public_ipv4

  depends_on = [talos_machine_configuration_apply.control_plane]
}

# Fetch kubeconfig once the cluster is bootstrapped.
resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_cp_node.public_ipv4
  endpoint             = local.first_cp_node.public_ipv4

  depends_on = [talos_machine_bootstrap.this]
}

# talosctl client configuration for break-glass / management.
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for n in local.cp_nodes : n.public_ipv4]
  nodes                = [for n in local.cp_nodes : n.public_ipv4]
}

# Optionally write kubeconfig + talosconfig to disk for direct CLI use.
# `local_sensitive_file` keeps the contents out of plan output.
resource "local_sensitive_file" "kubeconfig" {
  count = var.kubeconfig_path != null ? 1 : 0

  filename        = var.kubeconfig_path
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  file_permission = "0600"
}

resource "local_sensitive_file" "talosconfig" {
  count = var.talosconfig_path != null ? 1 : 0

  filename        = var.talosconfig_path
  content         = data.talos_client_configuration.this.talos_config
  file_permission = "0600"
}
