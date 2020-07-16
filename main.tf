variable "hcloud_token" {}
variable "cloudflare_email" {}
variable "cloudflare_api_token" {}
variable "nodecount" {}

locals {
  domain = "kube.tibor.host"
  names = [for i in range(var.nodecount) : format("%s%02d", "node", i)]
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  email = var.cloudflare_email
  api_token = var.cloudflare_api_token
}

data "cloudflare_zones" "tibor_host" {
  filter {
    name = "tibor.host*"
  }
}

resource "hcloud_ssh_key" "terraform" {
	name = "Terraform ssh key"
	public_key = file("ssh_key.pub")
}

resource "hcloud_server" "nodes" {
  for_each = toset(local.names)
  name = each.value
  image = "ubuntu-18.04"
  server_type = "cx21"
  ssh_keys = [hcloud_ssh_key.terraform.id]
	user_data = file("userdata.cloudinit")

  provisioner "remote-exec" {
    connection {
      type = "ssh"
      user = "root"
      private_key = file("ssh_key")
      host = self.ipv4_address
    }
    inline = [
      "cloud-init status --wait"
    ]
  }
}

resource "hcloud_volume" "volumes" {
  for_each = hcloud_server.nodes
  name = "volume_${each.value.name}"
  server_id = each.value.id
  size = 64
  automount = false
}

resource "cloudflare_record" "nodes" {
  for_each = hcloud_server.nodes
  zone_id = lookup(data.cloudflare_zones.tibor_host.zones[0], "id")
  name    = "${each.value.name}.${local.domain}"
  type    = "A"
  value   = each.value.ipv4_address
}

resource "rke_cluster" "cluster" {
  dynamic nodes {
    for_each = hcloud_server.nodes
    content {
      address = nodes.value.ipv4_address
      user    = "root"
      role    = ["etcd", "worker", "controlplane"]
      ssh_key = file("./ssh_key")
    }
  }
  network {
    plugin    = "weave"
  }
  ingress {
    provider  = "nginx"
  }

  addons_include = [
    "https://github.com/jetstack/cert-manager/releases/download/v0.13.0/cert-manager-no-webhook.yaml",
    "https://raw.githubusercontent.com/rook/rook/release-1.2/cluster/examples/kubernetes/ceph/common.yaml",
    "https://raw.githubusercontent.com/rook/rook/release-1.2/cluster/examples/kubernetes/ceph/operator.yaml",
    "./addons/external-dns.yaml",
    "./addons/letsencrypt-clusterissuer.yaml",
    "./addons/rook-ceph/cluster.yaml",
    "./addons/rook-ceph/ingress.yaml",
    "./addons/rook-ceph/storageclass-cephfs.yaml"
  ]
}

resource "local_file" "kube_cluster_yaml" {
  filename = "${path.root}/kube_config_cluster.yml"
  content = rke_cluster.cluster.kube_config_yaml
}

resource "local_file" "rke_cluster_yaml" {
  filename = "${path.root}/rke_cluster.yml"
  content = rke_cluster.cluster.rke_cluster_yaml
}
