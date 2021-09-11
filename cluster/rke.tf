variable nodes {
  type = map(any)
  default = {}
}
variable ssh_key {
  type = map(string)
  default = {}
}

provider "rke" {
  log_file = "${path.root}/log/rke.log"
}

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
