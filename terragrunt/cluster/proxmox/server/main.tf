locals {
  talos_image_url = "https://factory.talos.dev/image/${var.talos_schematic_id}/v${var.talos_version}/nocloud-amd64.iso"
}

resource "proxmox_download_file" "talos" {
  content_type = "iso"
  datastore_id = var.image_datastore
  node_name    = var.proxmox_node
  file_name    = "talos-v${var.talos_version}-nocloud-amd64.iso"
  url          = local.talos_image_url
  overwrite    = false
}

resource "proxmox_virtual_environment_file" "user_data" {
  for_each = var.workers

  content_type = "snippets"
  datastore_id = var.snippets_datastore
  node_name    = var.proxmox_node

  source_raw {
    data      = var.worker_machine_configs[each.key]
    file_name = "talos-${each.key}-user-data.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "worker" {
  for_each = var.workers

  name      = each.key
  node_name = var.proxmox_node
  vm_id     = each.value.vm_id
  tags      = ["talos", "kubernetes", "proxmox-worker"]

  on_boot         = true
  stop_on_destroy = true

  boot_order = ["virtio0", "ide3"]

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory
  }

  cdrom {
    file_id   = proxmox_download_file.talos.id
    interface = "ide3"
  }

  disk {
    datastore_id = var.vm_datastore
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = each.value.disk_size
    file_format  = "raw"
  }

  disk {
    datastore_id = var.vm_datastore
    interface    = "virtio1"
    iothread     = true
    discard      = "on"
    size         = each.value.data_disk_size
    file_format  = "raw"
  }

  network_device {
    bridge = var.network_bridge
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = var.vm_datastore

    user_data_file_id = proxmox_virtual_environment_file.user_data[each.key].id

    ip_config {
      ipv4 {
        address = "${each.value.ip}/${var.network_cidr}"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = var.nameservers
    }
  }

  depends_on = [terraform_data.node_evict]
}

resource "terraform_data" "untaint" {
  triggers_replace = {
    nodes = join(",", sort(keys(var.workers)))
  }

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = "${path.module}/../../scripts/wait-and-untaint.sh ${join(" ", sort(keys(var.workers)))}"
  }

  depends_on = [proxmox_virtual_environment_vm.worker]
}

resource "terraform_data" "node_drain" {
  for_each = var.workers

  triggers_replace = {
    vm_id      = proxmox_virtual_environment_vm.worker[each.key].id
    node       = each.key
    kubeconfig = var.kubeconfig_path
  }

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue

    environment = {
      KUBECONFIG = self.triggers_replace.kubeconfig
    }

    command = <<-EOT
      node="${self.triggers_replace.node}"
      kubectl cordon "$node" || true
      kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --timeout=120s || true
      kubectl delete node "$node" --timeout=60s || true
    EOT
  }
}

resource "terraform_data" "node_evict" {
  for_each = var.workers

  triggers_replace = {
    node       = each.key
    kubeconfig = var.kubeconfig_path
  }

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue

    environment = {
      KUBECONFIG = self.triggers_replace.kubeconfig
    }

    command = "kubectl delete node \"${self.triggers_replace.node}\" --timeout=60s || true"
  }
}
