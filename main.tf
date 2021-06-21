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
  log_file = "rke.log"
}

data "cloudflare_zones" "zone" {
  filter {
    name = local.domain
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
  location = "nbg1"
  keep_disk = true

  labels = {
    type = "kube-node"
    terraform = "true"
  }

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

/* resource "hcloud_volume" "volumes" { */
/*   for_each = hcloud_server.nodes */
/*   name = "volume_${each.value.name}" */
/*   server_id = each.value.id */
/*   size = 64 */
/*   automount = false */
/* } */

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
