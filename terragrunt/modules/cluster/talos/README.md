# `cluster/talos` module

Turns the generic node inventory from `00-machines` into a running Talos Kubernetes cluster.

## What this layer does

1. Waits for each CP node's Talos maintenance API (TCP 50000) to be reachable.
2. Generates cluster-wide secrets (cluster CA, etcd CA, machine CA, k8s CA).
3. Builds a Talos machine config for each control-plane node, with the project-wide patches:
   - `cni: none` — Cilium installs in `30-networking`
   - `proxy: disabled` — Cilium replaces kube-proxy
   - `externalCloudProvider: enabled` — kubelet uses `cloud-provider=external`; Hetzner CCM installs in `30-networking`
4. Applies the config to each node via `talosctl --insecure` (the provider does this implicitly while the node is in maintenance mode).
5. Bootstraps etcd on the first CP node (one-shot, idempotent on re-apply).
6. Fetches kubeconfig once the cluster is up.

## What this layer does NOT do

- No CNI install. Cluster boots with no working pod networking — that's `30-networking`'s job.
- No CCM install. Nodes will be `NotReady` with the `node.cloudprovider.kubernetes.io/uninitialized` taint until Hetzner CCM is installed in `30-networking`.
- No worker nodes. Single-node milestone 1.
- No etcd snapshot scheduling. That's part of the milestone-1 backup work (step 6) alongside Velero.
- No kube-apiserver OIDC. That's M2 once Authentik is up.

## Inputs

See `variables.tf`. Required: `cluster_name`, `nodes`, `talos_version`.

`cluster_endpoint` defaults to `https://<first-cp-public-ipv4>:6443` if null. Override only when you have HA + an external load balancer.

## Outputs

- `kubeconfig` (sensitive) — for kubectl
- `talosconfig` (sensitive) — for talosctl
- `cluster_endpoint`, `cluster_name`, `cluster_ca_certificate`, `talos_version`

## Notes

- **Maintenance-mode wait**: `terraform_data.wait_for_maintenance` polls TCP 50000 with bash's `/dev/tcp`, no external tool. If your apply runner doesn't have bash, replace with `nc` or `curl --connect-timeout`.
- **Bootstrap idempotency**: `talos_machine_bootstrap` will error if etcd is already bootstrapped. The provider catches the "already bootstrapped" case and treats it as a no-op.
- **Re-apply behaviour**: changing the machine config triggers `talos_machine_configuration_apply` to push the new config; Talos handles config reload without re-bootstrap.
- **Kubeconfig in state**: `talos_cluster_kubeconfig` stores the kubeconfig in TF state. Reasonable for the PoC; revisit when state encryption arrives in M2.
