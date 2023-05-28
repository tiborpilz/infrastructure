module "metallb" {
  source          = "./modules/metallb"
  ips             = var.ingress_ips
  metallb_version = "v0.13.9"
}

module "hcloud_csi" {
  source       = "./modules/hcloud-csi"
  hcloud_token = var.hcloud_token
}

module "keycloak" {
  source           = "./modules/keycloak"
  keycloak_version = "21.1.1"
  domain           = var.domain
  default_password = var.secrets.admin_password
}

module "cert_manager" {
  source               = "./modules/cert-manager"
  cert_manager_version = "v1.9.1"
  email                = var.email
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
  kubernetes_version = "v1.24.10-rancher4-1"
  network {
    plugin = "weave"
  }
  ingress {
    provider = "none"
  }
  addons_include = concat(
    ["https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.7.1/deploy/static/provider/cloud/deploy.yaml"],
    module.cert_manager.files,
    module.metallb.files,
    module.hcloud_csi.files,
    module.keycloak.files,
  )
  services {
    kube_api {
      extra_args = {
        "oidc-issuer-url" = "https://keycloak.${var.domain}/realms/default"
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
  enable_cri_dockerd    = true
  ignore_docker_version = true

  provisioner "local-exec" {
    command    = "while true; do curl -k 'https://keycloak.${var.domain}' && break || sleep 3; done"
    on_failure = continue
  }
}

resource "local_file" "kube_cluster_yaml" {
  filename = "${path.root}/../out/kube_config_cluster.yml"
  content  = rke_cluster.cluster.kube_config_yaml
}

resource "local_file" "rke_cluster_yaml" {
  filename = "${path.root}/../out/rke_cluster.yml"
  content  = rke_cluster.cluster.rke_cluster_yaml
}
