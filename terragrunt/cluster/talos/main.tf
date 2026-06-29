module "bootstrap" {
  source = "./bootstrap"

  admin_email          = var.admin_email
  kubernetes_version   = coalesce(var.kubernetes_version, "1.30.0")
  hcloud_token         = var.hcloud_token
  domain               = var.domain
  location             = var.location
  cloudflare_api_token = var.cloudflare_api_token
  network_name         = var.network_name
  argocd_age_key       = var.argocd_age_key
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

  base_patch = yamlencode({
    machine = {
      sysctls = {
        "user.max_user_namespaces" = "63359"
      }
      network = {
        kubespan = {
          enabled                     = true
          advertiseKubernetesNetworks = false
        }
      }
    }
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
      discovery = {
        enabled = true
      }
    }
  })

  proxmox_subnet = var.proxmox_network_gateway != null ? "${cidrhost("${var.proxmox_network_gateway}/${var.proxmox_network_cidr}", 0)}/${var.proxmox_network_cidr}" : null

  bootstrap_patch = yamlencode({
    cluster = {
      inlineManifests = module.bootstrap.inline_manifests
    }
  })

  bootstrap_manifests_hash = md5(jsonencode(module.bootstrap.inline_manifests))
}

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
          "storage.longhorn.io/eligible" = "true"
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

data "talos_machine_configuration" "proxmox_worker" {
  for_each = var.proxmox_workers

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
        install = {
          disk  = each.value.install_disk
          image = "factory.talos.dev/installer/${var.proxmox_talos_schematic_id}:v${var.talos_version}"
        }
        network = {
          hostname = each.key
          interfaces = [{
            deviceSelector = { physical = true }
            dhcp           = false
            addresses      = ["${each.value.ip}/${var.proxmox_network_cidr}"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = var.proxmox_network_gateway
            }]
          }]
          nameservers = var.proxmox_nameservers
        }
        kubelet = {
          nodeIP    = { validSubnets = [local.proxmox_subnet] }
          extraArgs = { "provider-id" = "proxmox://${each.key}" } # non-hcloud provider-id makes the hcloud CCM error rather than delete these nodes
        }
        nodeLabels = {
          "node.tibor.sh/tier" = "proxmox"
        }
      }
      cluster = {
        externalCloudProvider = { enabled = false }
      }
    }),
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      "$patch"   = "delete"
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

resource "local_file" "bootstrap_manifests" {
  count = var.bootstrap_manifests_path != null ? 1 : 0

  filename        = var.bootstrap_manifests_path
  content         = module.bootstrap.rendered_yaml
  file_permission = "0644"
}

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

resource "random_password" "authentik_valkey" {
  length  = 32
  special = false
}

resource "random_password" "authentik_bootstrap_token" {
  length  = 40
  special = false
}

resource "random_password" "argocd_oidc_client_secret" {
  length  = 48
  special = false
}

resource "terraform_data" "app_secrets" {
  triggers_replace = [
    sha256(var.authentik_secret_key),
    sha256(random_password.authentik_valkey.result),
    sha256(random_password.authentik_bootstrap_token.result),
    sha256(random_password.argocd_oidc_client_secret.result),
  ]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG                = local_sensitive_file.kubeconfig[0].filename
      AUTHENTIK_SECRET_KEY      = var.authentik_secret_key
      VALKEY_PASSWORD           = random_password.authentik_valkey.result
      AUTHENTIK_BOOTSTRAP_TOKEN = random_password.authentik_bootstrap_token.result
      ARGOCD_OIDC_CLIENT_SECRET = random_password.argocd_oidc_client_secret.result
    }
    command = <<-BASH
      kubectl create namespace authentik --dry-run=client -o yaml | kubectl apply -f -
      kubectl create secret generic authentik-bootstrap \
        --namespace=authentik \
        --from-literal=AUTHENTIK_SECRET_KEY="$AUTHENTIK_SECRET_KEY" \
        --from-literal=AUTHENTIK_BOOTSTRAP_TOKEN="$AUTHENTIK_BOOTSTRAP_TOKEN" \
        --from-literal=AUTHENTIK_REDIS__HOST=authentik-valkey \
        --from-literal=AUTHENTIK_REDIS__PASSWORD="$VALKEY_PASSWORD" \
        --from-literal=AUTHENTIK_POSTGRESQL__HOST=authentik-db-rw \
        --from-literal=AUTHENTIK_POSTGRESQL__USER=authentik \
        --from-literal=AUTHENTIK_POSTGRESQL__NAME=authentik \
        --from-literal=AUTHENTIK_POSTGRESQL__PORT=5432 \
        --dry-run=client -o yaml | kubectl apply -f -
      kubectl create secret generic authentik-valkey \
        --namespace=authentik \
        --from-literal=password="$VALKEY_PASSWORD" \
        --dry-run=client -o yaml | kubectl apply -f -
      kubectl apply -f - <<EOF
      apiVersion: v1
      kind: Secret
      metadata:
        name: authentik-oidc-clients
        namespace: authentik
        annotations:
          reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
          reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "argocd"
          reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
          reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: "argocd"
      type: Opaque
      stringData:
        ARGOCD_OIDC_CLIENT_SECRET: "$ARGOCD_OIDC_CLIENT_SECRET"
      EOF
    BASH
  }

  depends_on = [terraform_data.wait_for_cluster]
}

resource "terraform_data" "cluster_autoscaler_bootstrap" {
  triggers_replace = [
    sha256(var.hcloud_token),
    sha256(data.talos_machine_configuration.worker_template.machine_configuration),
    var.hcloud_image_id,
    var.hcloud_network_id,
    var.hcloud_firewall_id,
  ]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG        = local_sensitive_file.kubeconfig[0].filename
      HCLOUD_TOKEN      = var.hcloud_token
      HCLOUD_CLOUD_INIT = base64encode(data.talos_machine_configuration.worker_template.machine_configuration)
      HCLOUD_IMAGE      = var.hcloud_image_id
      HCLOUD_NETWORK    = var.hcloud_network_id
      HCLOUD_FIREWALL   = var.hcloud_firewall_id
    }
    command = <<-BASH
      kubectl create namespace cluster-autoscaler --dry-run=client -o yaml | kubectl apply -f -
      kubectl create configmap cluster-autoscaler-config \
        --namespace=cluster-autoscaler \
        --from-literal=HCLOUD_IMAGE="$HCLOUD_IMAGE" \
        --from-literal=HCLOUD_NETWORK="$HCLOUD_NETWORK" \
        --from-literal=HCLOUD_FIREWALL="$HCLOUD_FIREWALL" \
        --dry-run=client -o yaml | kubectl apply -f -
      kubectl create secret generic cluster-autoscaler-hcloud \
        --namespace=cluster-autoscaler \
        --from-literal=HCLOUD_TOKEN="$HCLOUD_TOKEN" \
        --from-literal=HCLOUD_CLOUD_INIT="$HCLOUD_CLOUD_INIT" \
        --dry-run=client -o yaml | kubectl apply -f -
    BASH
  }

  depends_on = [terraform_data.wait_for_cluster]
}

resource "terraform_data" "cilium_lb_pool" {
  triggers_replace = {
    floating_ip = var.floating_ip_address
  }

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = local_sensitive_file.kubeconfig[0].filename
    }
    command = "${path.module}/../scripts/apply-cilium-lb-pool.sh ${var.floating_ip_address}"
  }

  depends_on = [terraform_data.wait_for_cluster]
}
