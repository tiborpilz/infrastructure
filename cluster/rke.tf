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
    "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.3.1/deploy/static/provider/baremetal/deploy.yaml",
  ]

  addons = <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: metallb-system
---
apiVersion: v1
kind: Secret
metadata:
  name: memberlist
  namespace: metallb-system
data:
  secretkey: "${var.metallb_secret}"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: config
  namespace: metallb-system
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      %{for ip in var.ingress_ips}
      - ${ip}/32
      %{endfor}
---
apiVersion: v1
kind: Secret
metadata:
  name: hcloud-csi
  namespace: kube-system
type: Opaque
data:
  token: "${base64encode(var.hcloud_token)}"
---
EOF
  # ssh_key_path       = "../out/sshkey"
  enable_cri_dockerd = true
}

resource "local_file" "kube_cluster_yaml" {
  filename = "${path.root}/../out/kube_config_cluster.yml"
  content  = rke_cluster.cluster.kube_config_yaml
}

resource "local_file" "rke_cluster_yaml" {
  filename = "${path.root}/../out/rke_cluster.yml"
  content  = rke_cluster.cluster.rke_cluster_yaml
}
