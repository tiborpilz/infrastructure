# First-boot NixOS install via nixos-anywhere.
#
# nixos-anywhere is destructive: it kexecs the live system, runs disko, and
# wipes the boot disk. We absolutely do NOT want this to re-run on every
# apply, only when the server is created or replaced. Hence triggers_replace
# keyed on the server ID — TF only re-runs the provisioner when that ID
# actually changes.
#
# Ongoing config updates go through deploy-rs, not this resource. See README.
resource "terraform_data" "nixos_anywhere" {
  triggers_replace = {
    server_id = hcloud_server.this.id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      target_ip="${hcloud_primary_ip.this.ip_address}"
      flake_ref='${var.flake_uri}#${local.effective_flake_host}'

      # Hetzner's debian-12 image boots quickly but sshd needs a moment.
      echo "Waiting for SSH on $target_ip..."
      for i in $(seq 1 60); do
        if ssh \
             -o StrictHostKeyChecking=accept-new \
             -o UserKnownHostsFile=/dev/null \
             -o ConnectTimeout=5 \
             -o BatchMode=yes \
             root@$target_ip true 2>/dev/null; then
          echo "SSH up on $target_ip"
          break
        fi
        echo "  attempt $i/60..."
        sleep 5
      done

      echo "Running nixos-anywhere against $flake_ref"
      exec nix \
        --extra-experimental-features 'nix-command flakes' \
        run github:nix-community/nixos-anywhere -- \
        --flake "$flake_ref" \
        --target-host "root@$target_ip" \
        --build-on local \
        ${join(" ", [for a in var.nixos_anywhere_extra_args : format("%q", a)])}
    EOT
  }

  depends_on = [
    hcloud_server.this,
    hcloud_server_network.this,
  ]
}
