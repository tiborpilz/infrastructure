module "metallb" {
  source          = "./modules/metallb"
  ips             = var.ingress_ips
  metallb_version = var.metallb_version
}

module "hcloud_csi" {
  source       = "./modules/hcloud-csi"
  hcloud_token = var.secrets.hcloud_token
}

module "keycloak" {
  source           = "./modules/keycloak"
  keycloak_version = var.keycloak_version
  domain           = var.domain
  default_password = var.secrets.keycloak_admin_password
}

module "cert_manager" {
  source               = "./modules/cert-manager"
  cert_manager_version = var.cert_manager_version
  email                = var.email
}

module "ingress_nginx" {
  source                = "./modules/ingress-nginx"
  ingress_nginx_version = var.ingress_nginx_version
}

resource "rke_cluster" "cluster" {
  dynamic "nodes" {
    for_each = var.nodes
    content {
      address        = nodes.value.ipv4_address
      user           = "root"
      role           = ["etcd", "worker", "controlplane"]
      ssh_key        = var.ssh_key.private_key_pem
    }
  }
  kubernetes_version = var.rke_kubernetes_version
  network {
    plugin = "weave"
  }
  ingress {
    provider = "none"
    # These values are not used, but if they're missing terraform will try to re-create the cluster on every apply
    http_port = 80
    https_port = 443
    network_mode = "hostPort"
  }
  addons_include = concat(
    module.ingress_nginx.files,
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
