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
  network {
    plugin = "weave"
  }
  ingress {
    provider = "none"
  }
  addons_include = [
    "https://github.com/cert-manager/cert-manager/releases/download/v1.9.1/cert-manager.yaml",
    "./addons/letsencrypt-clusterissuer.yaml",
    "https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml",
    "https://raw.githubusercontent.com/hetznercloud/csi-driver/master/deploy/kubernetes/hcloud-csi.yml",
    "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.5.1/deploy/static/provider/cloud/deploy.yaml",
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
  enable_cri_dockerd = true

  provisioner "local-exec" {
    command    = "while true; do curl -k 'https://auth.bababourbaki.dev' && break || sleep 3"
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
