/**
 * # Hetzner
 *
 * This module takes care of creating the Hetzner Cloud servers and connecting them to external IPs.
 */
variable "hcloud_token" {
  type        = string
  description = "The hetzner cloud token to use"
}

variable "nodes" {
  type    = map(any)
  description = "Kubernetes nodes definitions"
}

terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.49.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
}

resource "local_file" "ssh_key" {
  filename        = "${path.root}/../out/sshkey"
  content         = tls_private_key.ssh_key.private_key_pem
  file_permission = "0600"
}

resource "hcloud_ssh_key" "terraform" {
  name       = "Terraform ssh key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}


resource "hcloud_server" "nodes" {
  for_each    = var.nodes
  name        = each.key
  image       = "docker-ce"
  server_type = each.value.type
  ssh_keys    = [hcloud_ssh_key.terraform.id]
  location    = "fsn1"
  keep_disk   = false

  labels = {
    type      = "kube-node"
    terraform = "true"
    etcd      = contains(each.value.role, "etcd") ? "true" : "false"
    controlplane   = contains(each.value.role, "controlplane") ? "true" : "false"
    worker    = contains(each.value.role, "worker") ? "true" : "false"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      private_key = tls_private_key.ssh_key.private_key_pem
      host        = self.ipv4_address
    }
    inline = [
      "echo 'done'"
    ]
  }
}

locals {
  worker_nodes     = { for key, node in hcloud_server.nodes : key => node if node.labels["worker"] == "true" }
  first_worker     = [for key, node in local.worker_nodes : node][0]
}

resource "hcloud_floating_ip" "floating_ip" {
  type      = "ipv4"
  server_id = local.first_worker.id

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      private_key = tls_private_key.ssh_key.private_key_pem
      host        = local.first_worker.ipv4_address

    }
    inline = [
      "sudo ip addr add ${self.ip_address} dev eth0"
    ]
  }
}

output "nodes" {
  value = hcloud_server.nodes
  description = "Hetzner Cloud VMs with their respective roles"
}

output "ssh_key" {
  value     = tls_private_key.ssh_key
  description = "Generated SSH key for the Hetzner Cloud VMs"
  sensitive = true
}

output "floating_ip" {
  value = hcloud_floating_ip.floating_ip.ip_address
  description = "The floating IP address of the first worker node"
}
