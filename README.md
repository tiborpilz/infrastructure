# Infrastructure

IaC repo for my personal Infrastructure.

Uses both Hetzner Cloud and Proxmox VMs to provision a Talos k8s Cluster with ArgoCD.

Additionally includes applications for ArgoCD to deploy.

## State encryption

State and plan files are encrypted client-side (`terragrunt/root.hcl`). The
passphrase comes from `state_passphrase` in `terragrunt/secrets.enc.yaml` or
`TF_STATE_PASSPHRASE`. To migrate existing unencrypted state: apply once per
unit, then set `state_encryption_migration = false`. Losing the passphrase
means losing the state.
