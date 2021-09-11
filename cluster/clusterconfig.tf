provider "kubernetes" {
  experiments {
    manifest_resource = true
  }

  host     = rke_cluster.cluster.api_server_url
  username = rke_cluster.cluster.kube_admin_user

  client_certificate     = rke_cluster.cluster.client_cert
  client_key             = rke_cluster.cluster.client_key
  cluster_ca_certificate = rke_cluster.cluster.ca_crt
}

resource "kubernetes_secret" "hcloud_csi" {
  metadata {
    name = "hcloud-csi"
    namespace = "kube-system"
  }
  data = {
    token = var.hcloud_token
  }
}

resource "kubernetes_config_map" "metallb_config" {
  metadata {
    name = "config"
    namespace = "metallb-system"
  }
  data = {
    config = <<EOF
      address-pools:
      - name: default
        protocol: layer2
        addresses:
        - ${var.ingress_ips[0]}/32
    EOF
  }
}

resource "kubernetes_secret" "metallb_memberlist" {
  metadata {
    name = "memberlist"
    namespace = "metallb-system"
  }
  data = {
    secretkey = var.metallb_secret
  }
}
