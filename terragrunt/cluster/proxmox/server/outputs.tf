output "workers" {
  description = "Proxmox worker inventory (informational). These nodes self-join over KubeSpan and are not part of the talos module's node list."
  value = {
    for k, v in var.workers : k => {
      name  = k
      ipv4  = v.ip
      vm_id = v.vm_id
      tier  = "proxmox"
    }
  }
}

output "vm_ids" {
  description = "Map of node name to Proxmox VM ID."
  value       = { for k, vm in proxmox_virtual_environment_vm.worker : k => vm.vm_id }
}
