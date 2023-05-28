provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_ssh_key" "terraform" {
  name       = "Terraform ssh key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "hcloud_server" "nodes" {
  for_each    = toset(local.names)
  name        = each.value
  image       = "docker-ce"
  server_type = "cx31"
  ssh_keys    = [hcloud_ssh_key.terraform.id]
  user_data   = templatefile("${path.module}/templates/userdata.cloudinit.tpl", {})
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

resource "hcloud_floating_ip" "floating_ip" {
  type      = "ipv4"
  server_id = hcloud_server.nodes[local.names[0]].id

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      private_key = tls_private_key.ssh_key.private_key_pem
      host        = hcloud_server.nodes[local.names[0]].ipv4_address
    }
    inline = [
      "sudo ip addr add ${self.ip_address} dev eth0"
    ]
  }
}
