# Infrastructure

IaC repo for my personal Infrastructure.

Uses both Hetzner Cloud and Proxmox VMs to provision a Talos k8s Cluster with ArgoCD.

Additionally includes applications for ArgoCD to deploy.

## Test cluster

`terragrunt/cluster-test` is a disposable copy of the stack for testing
changes: the same `terragrunt/cluster` module on a single small Hetzner VM
(one control plane with workload scheduling enabled), with its own state
(`.terragrunt-state/cluster-test`), its own network and floating IP, and DNS
under `*.test.<domain>` with a separate external-dns owner id — applying and
destroying it never touches the main cluster.

The Talos snapshot must already exist in the Hetzner project
(`setup/upload-talos-image.sh`).

```sh
cd terragrunt/cluster-test
terragrunt apply

export KUBECONFIG="$(git rev-parse --show-toplevel)/.kube/hcloud-test.kubeconfig"
kubectl get nodes
# ArgoCD comes up on https://argocd.test.<domain>

terragrunt destroy
```

## State encryption

State and plan files are encrypted client-side (`terragrunt/root.hcl`). The
passphrase comes from `state_passphrase` in `terragrunt/secrets.enc.yaml` or
`TF_STATE_PASSPHRASE`. To migrate existing unencrypted state: apply once per
unit, then set `state_encryption_migration = false`. Losing the passphrase
means losing the state.
