resource "rke_cluster" "cluster" {
  dynamic nodes {
    for_each = var.nodes
    content {
      address = nodes.value.ipv4_address
      user    = "root"
      role    = ["etcd", "worker", "controlplane"]
      ssh_key = var.ssh_key.private_key_pem
    }
  }
  network {
    plugin    = "weave"
  }
  ingress {
    provider  = "none"
  }

  addons_include = [
    "https://github.com/jetstack/cert-manager/releases/download/v0.13.0/cert-manager-no-webhook.yaml",
    "https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml",
    "https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml",
    "./addons/letsencrypt-clusterissuer.yaml",
    "https://raw.githubusercontent.com/hetznercloud/csi-driver/master/deploy/kubernetes/hcloud-csi.yml",
    "https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/olm.yaml",
    "https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/crds.yaml",
  ]
}

resource "local_file" "kube_cluster_yaml" {
  filename = "${path.root}/../out/kube_config_cluster.yml"
  content = rke_cluster.cluster.kube_config_yaml
}

resource "local_file" "rke_cluster_yaml" {
  filename = "${path.root}/../out/rke_cluster.yml"
  content = rke_cluster.cluster.rke_cluster_yaml
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
        %{ for ip in var.ingress_ips }
        - ${ip}/32
        %{ endfor }
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
