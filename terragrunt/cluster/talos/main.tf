locals {
  control_plane_nodes      = var.nodes.control_plane
  worker_nodes             = var.nodes.workers
  first_control_plane_key  = sort(keys(local.control_plane_nodes))[0]
  first_control_plane_node = local.control_plane_nodes[local.first_control_plane_key]

  effective_endpoint = coalesce(
    var.cluster_endpoint,
    "https://${local.first_control_plane_node.public_ipv4}:6443",
  )

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

# Hack to wait for Talos maintenance API (TCP 50000) on each control-plane to be up.
resource "terraform_data" "wait_for_maintenance" {
  for_each = local.control_plane_nodes

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

resource "talos_machine_secrets" "this" {
  talos_version = "v${var.talos_version}"
}

data "talos_machine_configuration" "control_plane" {
  for_each = local.control_plane_nodes

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
        nodeLabels = {
          "storage.longhorn.io/eligible" = "true"
        }
      }
    }),
  ]
}

resource "talos_machine_configuration_apply" "control_plane" {
  for_each = local.control_plane_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane[each.key].machine_configuration
  node                        = each.value.public_ipv4

  depends_on = [terraform_data.wait_for_maintenance]
}
#
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

  # `storage.longhorn.io/eligible=true` opts this node into hosting Longhorn
  # system components. Burst nodes provisioned by cluster-autoscaler use the
  # `worker_template` config below, which omits this label — keeping Longhorn
  # (manager + instance-manager) off them so their instance-manager PDB can't
  # block scale-down.
  config_patches = [
    local.base_patch,
    yamlencode({
      machine = {
        install = { disk = each.value.install_disk }
        nodeLabels = {
          "storage.longhorn.io/eligible" = "true"
        }
      }
    }),
  ]
}

# Generic worker MachineConfig with no per-node specifics. Consumed by the
# cluster-autoscaler in the platform layer as cloud-init user-data for
# autoscaler-provisioned Hetzner servers. /dev/sda matches all Hetzner CPX
# workers; if a new server type with different naming appears, parameterise.
data "talos_machine_configuration" "worker_template" {
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
        install = { disk = "/dev/sda" }
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
    talos_machine_bootstrap.this,
  ]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_control_plane_node.public_ipv4
  endpoint             = local.first_control_plane_node.public_ipv4
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_control_plane_node.public_ipv4
  endpoint             = local.first_control_plane_node.public_ipv4
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for n in local.control_plane_nodes : n.public_ipv4]
  nodes                = [for n in local.control_plane_nodes : n.public_ipv4]
}

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

# Bootstrap returns once etcd is initialized, and config_apply returns once
# Talos has accepted the machine config — neither waits for the apiserver to
# be fully responsive or for the kubelet on each node to register. Platform
# hits the API before that and stalls. Block here until /healthz is OK and
# every expected node is visible (NotReady is fine — CNI is platform's job).
resource "terraform_data" "wait_for_cluster" {
  triggers_replace = {
    nodes = join(",", concat(
      [for k, _ in local.control_plane_nodes : k],
      [for k, _ in local.worker_nodes : k],
    ))
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      KUBECONFIG = local_sensitive_file.kubeconfig[0].filename
    }
    command = <<-EOT
      set -euo pipefail

      for i in $(seq 1 60); do
        if kubectl get --raw /healthz >/dev/null 2>&1; then
          echo "apiserver /healthz OK"
          break
        fi
        echo "waiting for apiserver (attempt $i/60)..."
        sleep 5
      done
      kubectl get --raw /healthz >/dev/null

      expected="${join(" ", concat(
    [for k, _ in local.control_plane_nodes : k],
    [for k, _ in local.worker_nodes : k],
))}"

      for i in $(seq 1 60); do
        missing=""
        for node in $expected; do
          if ! kubectl get node "$node" >/dev/null 2>&1; then
            missing="$missing $node"
          fi
        done
        if [ -z "$missing" ]; then
          echo "all nodes registered: $expected"
          exit 0
        fi
        echo "waiting for nodes to register, missing:$missing (attempt $i/60)..."
        sleep 5
      done
      echo "nodes never registered within 5 minutes: $missing" >&2
      exit 1
    EOT
}

depends_on = [
  talos_cluster_kubeconfig.this,
  talos_machine_configuration_apply.worker,
  local_sensitive_file.kubeconfig,
]
}
