terraform {
  required_version = ">= 1.7"

  # Only the proxmox provider is configured at this root (for the ssh block used
  # to upload Talos user-data snippets). Other providers (helm, hcloud, talos,
  # cloudflare) resolve from the child modules that declare and use them.
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.95"
    }
  }
}
