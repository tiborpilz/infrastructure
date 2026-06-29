locals {
  # nocloud ISO from the Talos Image Factory. VMs boot it into maintenance mode,
  # read their MachineConfig from the cloud-init user-data, then install to disk.
  talos_image_url = "https://factory.talos.dev/image/${var.talos_schematic_id}/v${var.talos_version}/nocloud-amd64.iso"
}

# Download the Talos nocloud ISO onto the Proxmox node (Proxmox API only).
resource "proxmox_download_file" "talos" {
  content_type = "iso"
  datastore_id = var.image_datastore
  node_name    = var.proxmox_node
  file_name    = "talos-v${var.talos_version}-nocloud-amd64.iso"
  url          = local.talos_image_url
  overwrite    = false
}

# Per-node Talos MachineConfig uploaded as a snippet. bpg writes snippets over
# SSH (the Proxmox API has no snippet-upload endpoint), so the provider needs an
# ssh block and the datastore needs the Snippets content type enabled. Talos
# nocloud reads this verbatim as its machine configuration on first boot.
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

# One VM per worker. Boots the Talos ISO (ide3); boot_order tries the disk
# (virtio0) first so it boots the installed system once Talos has written it.
resource "proxmox_virtual_environment_vm" "worker" {
  for_each = var.workers

  name      = each.key
  node_name = var.proxmox_node
  vm_id     = each.value.vm_id
  tags      = ["talos", "kubernetes", "proxmox-worker"]

  on_boot         = true
  stop_on_destroy = true

  boot_order = ["virtio0", "ide3"]

  # Image includes qemu-guest-agent (see talos install.image); bpg hangs on
  # refresh if the agent never answers.
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
    # LVM storage requires raw (qcow2 is the bpg default).
    file_format = "raw"
  }

  # Raw data disk for the Rook-Ceph OSD. Talos exposes virtio1 as /dev/vdb, which
  # the CephCluster storage.nodes list claims. Empty; Rook wipes and consumes it.
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

    # The Talos worker config is the cloud-init user-data, so the NAT'd node
    # self-applies on boot without any inbound Talos API access.
    user_data_file_id = proxmox_virtual_environment_file.user_data[each.key].id

    # Static IP for the brief window before the Talos config network applies.
    # The same address is set in the Talos config, so it persists.
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

  # Destroyed before node_evict, so its delete runs after the kubelet is gone.
  depends_on = [terraform_data.node_evict]
}

# These nodes register with the external-cloud-provider "uninitialized" taint
# (machine.externalCloudProvider is on cluster-wide) and no CCM clears it for
# them — hcloud-ccm only manages hcloud nodes. Remove it once they register so
# pods can schedule. Re-runs if the node set changes (e.g. a node is rebuilt).
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

# Before a worker VM is destroyed or replaced: cordon, drain, delete the node.
# Nothing else removes the stale Node (not CCM-managed), and a same-name replace
# would otherwise inherit the cordon. Pinned to vm_id so it fires on replace too;
# node name + kubeconfig live in triggers_replace because destroy-time
# provisioners can read only self.
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

# Final delete after the VM is gone (worker depends_on this, inverting teardown
# order) so the dead kubelet can't re-register the node. Keyed on name only, so
# it fires on removal; replaces are covered by node_drain's delete.
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
