locals {
  template_out              = "${path.root}/templates-out"
  metallb_address_pool_file = "${local.template_out}/metallb_address_pool.yaml"
  hcloud_token_file         = "${local.template_out}/hcloud_token.yaml"
}

resource "local_file" "metallb_address_pool" {
  filename = local.metallb_address_pool_file
  content = templatefile("${path.root}/templates/metallb-ip-address-pool.tpl.yaml", {
    ingress_ips = var.ingress_ips
  })
}


resource "local_file" "hcloud_token" {
  filename = local.hcloud_token_file
  content = templatefile("${path.root}/templates/hcloud_token.tpl.yaml", {
    hcloud_token = var.hcloud_token
  })
}

resource "rke_cluster" "cluster" {
  dynamic "nodes" {
    for_each = var.nodes
    content {
      address        = nodes.value.ipv4_address
      user           = "root"
      role           = ["etcd", "worker", "controlplane"]
      ssh_key        = var.ssh_key.private_key_pem
      ssh_agent_auth = true
    }
  }
  kubernetes_version = "v1.21.14-rancher1-1"
  network {
    plugin = "weave"
  }
  ingress {
    provider = "none"
  }
  addons_include = [
    # Cert Manager
    "https://github.com/cert-manager/cert-manager/releases/download/v1.9.1/cert-manager.yaml",
    "./addons/letsencrypt-clusterissuer.yaml",

    # MetalLB
    "https://raw.githubusercontent.com/metallb/metallb/v0.13.9/config/manifests/metallb-native.yaml",
    local.metallb_address_pool_file,

    # Hcloud CSI
    "https://raw.githubusercontent.com/hetznercloud/csi-driver/master/deploy/kubernetes/hcloud-csi.yml",
    local.hcloud_token_file,

    # Ingress Nginx
    "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.5.1/deploy/static/provider/cloud/deploy.yaml",

    # Keycloak
    "./addons/keycloak-operator.yaml",
    "./addons/keycloak-base.yaml",
  ]
  services {
    kube_api {
      extra_args = {
        "oidc-issuer-url" = "https://auth.${var.domain}/auth/realms/default"
        "oidc-client-id"  = "kubernetes"
      }
    }
  }
  upgrade_strategy {
    drain                        = true
    max_unavailable_worker       = "100%"
    max_unavailable_controlplane = "100%"
    drain_input {
      delete_local_data  = true
      force              = true
      ignore_daemon_sets = true
      timeout            = 120
    }
  }
  addons = templatefile("${path.module}/addon_template.yaml", {
    metallb_secret = var.metallb_secret
    ingress_ips    = var.ingress_ips
    hcloud_token   = var.hcloud_token
  })
  # ssh_key_path       = "../out/sshkey"
  enable_cri_dockerd    = true
  ignore_docker_version = true

  # provisioner "local-exec" {
  #   command    = "while true; do curl -k 'https://auth.bababourbaki.dev' && break || sleep 3; done"
  #   on_failure = continue
  # }
}

resource "local_file" "kube_cluster_yaml" {
  filename = "${path.root}/../out/kube_config_cluster.yml"
  content  = rke_cluster.cluster.kube_config_yaml
}

resource "local_file" "rke_cluster_yaml" {
  filename = "${path.root}/../out/rke_cluster.yml"
  content  = rke_cluster.cluster.rke_cluster_yaml
}
