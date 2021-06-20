variable "hcloud_token" {}
variable "cloudflare_email" {}
variable "cloudflare_api_token" {}
variable "nodecount" {}
variable "metallb_secret" {}

terraform {
  required_providers {
    rke = {
      source = "rancher/rke"
    }
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    kustomization = {
      source = "kbst/kustomization"
    }
  }
}
locals {
  domain = "tiborpilz.dev"
  names = [for i in range(var.nodecount) : format("%s%02d", "node", i)]
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  email = var.cloudflare_email
  api_token = var.cloudflare_api_token
}

provider "rke" {
  debug = true
  log_file = "rke.log"
}

data "cloudflare_zones" "zone" {
  filter {
    name = local.domain
  }
}
data "hcloud_image" "rke_image" {
  with_selector = "type=rke_node"
}

resource "hcloud_ssh_key" "terraform" {
	name = "Terraform ssh key"
	public_key = file("ssh_key.pub")
}

resource "hcloud_server" "nodes" {
  for_each = toset(local.names)
  name = each.value
  image = "ubuntu-18.04"
  server_type = "cx31"
  ssh_keys = [hcloud_ssh_key.terraform.id]
	user_data = file("userdata.cloudinit")
  location = "nbg1"

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

resource "hcloud_floating_ip" "floating_ip" {
  type = "ipv4"
  server_id = hcloud_server.nodes[local.names[0]].id

  provisioner "remote-exec" {
    connection {
      type = "ssh"
      user = "root"
      private_key = file("ssh_key")
      host = hcloud_server.nodes[local.names[0]].ipv4_address
    }
    inline = [
      "sudo ip addr add ${self.ip_address} dev eth0"
    ]
  }
}


resource "cloudflare_record" "nodes" {
  for_each = hcloud_server.nodes
  zone_id = lookup(data.cloudflare_zones.zone.zones[0], "id")
  name    = "${each.value.name}.kube.${local.domain}"
  type    = "A"
  value   = each.value.ipv4_address
}

resource "cloudflare_record" "ingress" {
  zone_id = lookup(data.cloudflare_zones.zone.zones[0], "id")
  name = "*.${local.domain}"
  type = "A"
  value = hcloud_floating_ip.floating_ip.ip_address
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
    provider  = "none"
  }

  addons_include = [
    "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.47.0/deploy/static/provider/cloud/deploy.yaml",
    "./addons/ingress-nginx/service.yaml",
    "https://github.com/jetstack/cert-manager/releases/download/v0.13.0/cert-manager-no-webhook.yaml",
    "https://raw.githubusercontent.com/rook/rook/release-1.2/cluster/examples/kubernetes/ceph/common.yaml",
    "https://raw.githubusercontent.com/rook/rook/release-1.2/cluster/examples/kubernetes/ceph/operator.yaml",
    "https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml",
    "https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml",
    "./addons/letsencrypt-clusterissuer.yaml",
    "./addons/rook-ceph/cluster.yaml",
    "./addons/rook-ceph/ingress.yaml",
    "./addons/rook-ceph/storageclass-cephfs.yaml"
  ]
}

provider "kubernetes" {
  host     = rke_cluster.cluster.api_server_url
  username = rke_cluster.cluster.kube_admin_user


  client_certificate     = rke_cluster.cluster.client_cert
  client_key             = rke_cluster.cluster.client_key
  cluster_ca_certificate = rke_cluster.cluster.ca_crt
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
        - ${hcloud_floating_ip.floating_ip.ip_address}/32
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

resource "local_file" "kube_cluster_yaml" {
  filename = "${path.root}/kube_config_cluster.yml"
  content = rke_cluster.cluster.kube_config_yaml
}

resource "local_file" "rke_cluster_yaml" {
  filename = "${path.root}/rke_cluster.yml"
  content = rke_cluster.cluster.rke_cluster_yaml
}

provider "kustomization" {
  kubeconfig_raw = rke_cluster.cluster.kube_config_yaml
}

data "kustomization" "weave-scope" {
  provider = kustomization
  path = "./applications/weave-scope"
}

resource "kustomization_resource" "weave-scope" {
  provider = kustomization
  for_each = data.kustomization.weave-scope.ids
  manifest = data.kustomization.weave-scope.manifests[each.value]
}
