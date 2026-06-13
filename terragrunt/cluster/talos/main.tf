module "bootstrap" {
  source = "./bootstrap"

  # helm template needs a concrete version; Talos picks its own when null.
  kubernetes_version   = coalesce(var.kubernetes_version, "1.30.0")
  hcloud_token         = var.hcloud_token
  domain               = var.domain
  location             = var.location
  cloudflare_api_token = var.cloudflare_api_token
  network_name         = var.network_name
}

locals {
  control_plane_nodes      = var.nodes.control_plane
  worker_nodes             = var.nodes.workers
  first_control_plane_key  = sort(keys(local.control_plane_nodes))[0]
  first_control_plane_node = local.control_plane_nodes[local.first_control_plane_key]

  effective_endpoint = coalesce(
    var.cluster_endpoint,
    "https://${local.first_control_plane_node.public_ipv4}:6443",
  )

  # Cluster-wide config patch.
  base_patch = yamlencode({
    cluster = {
      allowSchedulingOnControlPlanes = var.allow_scheduling_on_control_planes
      network = {
        cni            = { name = "none" } # We're gonna use Cilium
        podSubnets     = [var.pod_cidr]
        serviceSubnets = [var.service_cidr]
        dnsDomain      = var.dns_domain
      }
      proxy = { disabled = true } # Cilium is going to replace kube-proxy.
      externalCloudProvider = {
        enabled = true
      }
    }
  })

  # Only control-plane configs get this; workers ignore inlineManifests.
  bootstrap_patch = yamlencode({
    cluster = {
      inlineManifests = module.bootstrap.inline_manifests
    }
  })

  # Hash of bootstrap manifests so Terraform detects when they change.
  # Used in triggers_replace to re-apply machine config when manifests are updated.
  bootstrap_manifests_hash = md5(jsonencode(module.bootstrap.inline_manifests))
}

# Wait for Talos maintenance API (TCP 50000) on each control-plane to be up.
resource "terraform_data" "wait_for_maintenance" {
  for_each = local.control_plane_nodes

  triggers_replace = {
    public_ipv4 = each.value.public_ipv4
  }

  provisioner "local-exec" {
    command = "${path.module}/../scripts/wait-for-maintenance.sh ${each.value.public_ipv4}"
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
    local.bootstrap_patch,
    yamlencode({
      machine = {
        install = { disk = each.value.install_disk }
        nodeLabels = {
          "storage.longhorn.io/eligible" = "true" # Enables Longhorn to run.
        }
      }
    }),
  ]
}

resource "terraform_data" "bootstrap_manifests_trigger" {
  triggers_replace = [
    local.bootstrap_manifests_hash,
  ]
}

resource "talos_machine_configuration_apply" "control_plane" {
  for_each = local.control_plane_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane[each.key].machine_configuration
  node                        = each.value.public_ipv4

  depends_on = [
    terraform_data.wait_for_maintenance,
    terraform_data.bootstrap_manifests_trigger,
  ]
}

resource "terraform_data" "wait_for_maintenance_worker" {
  for_each = local.worker_nodes

  triggers_replace = {
    public_ipv4 = each.value.public_ipv4
  }

  provisioner "local-exec" {
    command = "${path.module}/../scripts/wait-for-maintenance.sh ${each.value.public_ipv4}"
  }
}

# Worker nodes that are with the cluster from the start, hence they are eligible for longhorn.
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
        nodeLabels = {
          "storage.longhorn.io/eligible" = "true"
        }
      }
    }),
  ]
}

# Generic worker MachineConfig with no per-node specifics, used for cluster autoscaler.
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
    terraform_data.bootstrap_manifests_trigger,
    talos_machine_bootstrap.this,
  ]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_control_plane_node.public_ipv4
  endpoint             = local.first_control_plane_node.public_ipv4

  # depends_on = [talos_machine_configuration_apply.control_plane]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_control_plane_node.public_ipv4
  endpoint             = local.first_control_plane_node.public_ipv4

  # depends_on = [talos_machine_bootstrap.this]
}

# talosctl client configuration manual intervention
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for n in local.control_plane_nodes : n.public_ipv4]
  nodes                = [for n in local.control_plane_nodes : n.public_ipv4]
}

# kubeconfig for manual intervention
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

# Need to actually wait ourselves for the nodes to be available cause Talos
# wilkl return earlier.
resource "terraform_data" "wait_for_cluster" {
  triggers_replace = {
    nodes = join(",", concat(
      [for k, _ in local.control_plane_nodes : k],
      [for k, _ in local.worker_nodes : k],
    ))
  }

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = local_sensitive_file.kubeconfig[0].filename
    }
    command = "${path.module}/../scripts/wait-for-cluster.sh ${join(" ", concat(
      [for k, _ in local.control_plane_nodes : k],
      [for k, _ in local.worker_nodes : k],
    ))}"
  }

  depends_on = [
    talos_cluster_kubeconfig.this,
    talos_machine_configuration_apply.worker,
    local_sensitive_file.kubeconfig,
  ]
}

resource "terraform_data" "cilium_lb_pool" {
  triggers_replace = {
    floating_ip = var.floating_ip_address
  }

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = local_sensitive_file.kubeconfig[0].filename
    }
    command = <<-EOT
      kubectl apply -f - <<YAML
      apiVersion: cilium.io/v2alpha1
      kind: CiliumLoadBalancerIPPool
      metadata:
        name: default
      spec:
        blocks:
          - start: ${var.floating_ip_address}
            stop: ${var.floating_ip_address}
      YAML
    EOT
  }

  depends_on = [terraform_data.wait_for_cluster]
}
