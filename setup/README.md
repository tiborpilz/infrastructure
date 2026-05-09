# `setup/` — one-time prerequisites

Scripts here run **before** any `terragrunt apply`. They prepare external state that Terraform / Terragrunt can't model directly (or shouldn't).

Run each script once per environment, or once per cadence the script's header documents (e.g. once per Talos version).

## Tools

The repository ships a Nix flake that pins every CLI used here. Enter the dev shell with:

```bash
nix develop      # one-shot
# or, with direnv:
direnv allow     # auto-loads on cd
```

The dev shell provides: `terragrunt`, `opentofu`, `hcloud`, `hcloud-upload-image`, `talosctl`, `kubectl`, `helm`, `argocd`, `sops`, `age`, `xz`, `curl`, `jq`.

## Scripts

### `upload-talos-image.sh`

Uploads a Talos snapshot to your Hetzner Cloud project. Idempotent — re-running with the same `TALOS_VERSION` and `ARCH` exits cleanly if the snapshot already exists.

Default invocation (computes schematic ID via factory.talos.dev with `siderolabs/hcloud` + `siderolabs/qemu-guest-agent`):

```bash
HCLOUD_TOKEN=... setup/upload-talos-image.sh
```

Run once per Talos version bump. The Talos version and architecture must stay in sync with `terragrunt/envs/<env>/env.hcl` — bump together.

Customize via env vars:

- `TALOS_VERSION` — default `v1.13.0`
- `ARCH` — default `amd64` (or `arm64`)
- `TALOS_EXTENSIONS` — space-separated list of factory extensions; default `siderolabs/qemu-guest-agent`. Hetzner Cloud platform support is in Talos core, no extension needed.
- `SCHEMATIC_ID` — pin a specific schematic; skips the API call
