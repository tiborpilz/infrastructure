# `machines/hcloud` module

Hetzner Cloud machines layer for `00-machines`. Produces:

- a private network + subnet
- a cluster firewall **only if `firewall_admin_ips` is non-empty** (Talos API + k8s API restricted to those CIDRs, ICMP open). Empty = no firewall, both APIs reachable from anywhere. Talos and k8s API are mTLS-only so this is functionally safe-but-noisy.
- a control-plane placement group (`spread`)
- a primary IPv4 per control-plane node (survives server rebuild)
- one `hcloud_server` per control-plane node, booted from a Talos snapshot, **no userdata**

## What this layer does NOT do

- No cluster bootstrap. Talos boots into maintenance mode; the next layer (`10-cluster/talos`) pushes config via `talosctl apply-config --insecure`.
- No DNS records. App DNS comes from `30-networking` via external-dns.
- No Hetzner LoadBalancer. Arrives with `30-networking`.
- No worker nodes. Single-node milestone 1.

## Prerequisites

1. Enter the dev shell: `nix develop` (or `direnv allow` once).
2. `HCLOUD_TOKEN` env var with read+write API access.
3. A Talos snapshot uploaded to your Hetzner project, labeled to match `talos_image_labels`. Run `setup/upload-talos-image.sh` from the repo root.

## Inputs

See `variables.tf`. Required: `env_name`, `talos_image_labels`, `firewall_admin_ips`, `control_plane_nodes`.

## Outputs

- `nodes` — generic node inventory matching the cross-provider contract in `PLAN.md`
- `network_id`, `subnet_id`, `firewall_id`, `placement_group_id`, `location`, `network_zone` — for downstream layers

## Notes

- **Network attach race**: `hcloud_server_network` has an explicit `depends_on = [hcloud_network_subnet.main]` to avoid the known Hetzner+Talos race where a server boots before the network is attached. Talos's DHCP retry on the private NIC is the second line of defence.
- **`ignore_changes = [image]`** on `hcloud_server`: image updates flow through Talos itself (`talosctl upgrade`), not server recreate. Re-uploading a newer Talos snapshot will not churn existing servers.
- **Location → network_zone mapping** is hardcoded in `main.tf.local.network_zone_for_location`. Extend the map when adding new locations.
- **No IPv6** on the public NIC. Skipped for milestone 1 simplicity. Re-enable in `main.tf` when needed.
