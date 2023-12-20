provider "hcloud" {
  token = var.secrets.hcloud_token
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
  nodes_with_roles = { for key, node in hcloud_server.nodes : key => merge(node, var.nodes[key]) }
  worker_nodes     = { for key, node in local.nodes_with_roles : key => node if contains(node.role, "worker") }
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
