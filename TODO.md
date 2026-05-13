# TODO

## Talos upgrade: hostname can drift to `talos-<hash>` after image swap

After running `talosctl upgrade --image factory.talos.dev/installer/<schematic>:vX.Y.Z` on a node, the rebooted node sometimes comes back registered as `talos-<random-hash>` instead of its configured name (`controlplane-1`, `worker-1`). Symptom: `kubectl get nodes` shows two entries: the old name `NotReady` (kubelet stopped posting), the new `talos-<hash>` Running. Root cause: the Hetzner platform-metadata-derived hostname (HostnameConfig with `auto: hcloud`) doesn't reliably apply across the A/B swap.

Tried codifying a fix in TF (`config_patches` pushing `HostnameConfig` doc with explicit hostname). Doesn't work because:
- v1alpha1 `machine.network.hostname` conflicts with the auto-created HostnameConfig (Talos rejects "static hostname is already set").
- A patch overriding the HostnameConfig doc itself merges hostname *in addition to* `auto`, hitting "auto and hostname cannot be set at the same time".
- `auto: ""` and `auto: null` fail validation ("does not belong to AutoHostnameKind values").
- Strategic-merge `$patch: replace` directive may or may not be supported by the Talos provider; not investigated further.

Manual recovery (proven, do this after every upgrade if hostname drift happens):
```bash
talosctl --talosconfig <talosconfig> -n <node-ip> edit machineconfig
# Find `kind: HostnameConfig`, delete the `auto: hcloud` line, add `hostname: <name>`
# Save + exit, choose `reboot` apply mode
kubectl uncordon <node-name>
kubectl delete node talos-<old-hash>  # prune zombie if present
```

Worth revisiting: investigate whether the Talos provider's `talos_image_factory_*` resources can be configured to generate a base config without `auto: hcloud` in HostnameConfig, or whether there's a patch directive that fully replaces a sub-document.

## Investigate the kube-hetzner SSH-only bootstrap pattern

`terraform-hcloud-kube-hetzner` declares no `kubernetes`, `helm`, or `kubectl` providers. It bootstraps and configures the cluster entirely through:

- `loafoe/ssh` provider + `terraform_data` with SSH `provisioner "file"` / `remote-exec`
- manifests scp'd to `/var/post_install/` on the first control plane
- `kubectl apply -k` run on the node, against `127.0.0.1:6443`
- k3s's built-in HelmChart CRD controller for in-cluster Helm installs (rendered server-side, not by the operator)

This sidesteps the provider chicken-and-egg entirely: no kubeconfig needed at plan time, no provider needs an endpoint that doesn't exist yet, and `terraform destroy` doesn't break when the endpoint disappears.

Implications for the current Talos-based plan in `PLAN.md`:

- Talos has no equivalent of k3s's HelmChart controller. The "render Helm in-cluster" trick doesn't translate.
- Talos's bootstrap is API-driven (`talosctl apply-config`, `talosctl bootstrap`), not SSH. The `talos` provider already does this without needing a kubernetes provider.
- The relevant transferable idea is narrower: keep Terraform out of Kubernetes resource management entirely. Let TF own machines + Talos config + ArgoCD bootstrap manifest, then hand off to ArgoCD via a single `kubectl apply -f bootstrap-app.yaml`. No `kubernetes_manifest`, no `helm_release` after that point.
- The current `PLAN.md` 30-core-apps layer uses `argocd_application.<name>` Terraform resources. Decide whether that's worth the provider dependency vs. a single root-app YAML committed to the repo and applied once.

Action: prototype the bootstrap with zero `kubernetes`/`helm`/`argocd` providers: only `hcloud`, `talos`, `local`, `cloudflare`, and one `terraform_data` that shells out `kubectl apply` for the ArgoCD root app. Compare ergonomics against the provider-driven version before committing to either.

## Provider/lockfile sync after adding a new provider

When you add a `required_providers` entry (especially in a child module), use `terragrunt init -upgrade` from the unit directory, not `tofu init` directly. Terragrunt copies the source files into `.terragrunt-cache/<hash>/...` on every run; `tofu init` in the source dir updates the source-side `.terraform.lock.hcl` but the cache still holds the previous snapshot, and tofu's next invocation reads the cache, sees the source's new providers, and errors with `Inconsistent dependency lock file`.

Recovery if it happens:

- `terragrunt init -upgrade` (preferred path, syncs source-to-cache)
- `rm -rf <unit>/.terragrunt-cache` then `terragrunt init` (nuclear, always works)

Trigger to remember the rule: any time `required_providers` in `versions.tf` (root or any child module under it) gains a new entry.

## OpenCost

Build small script to estimate cost and plumb it into OpenCost https://opencost.io/

## CrossPlane & CrossView
https://github.com/crossplane-contrib/crossview

## https://kyverno.io/


## CI

Host
https://github.com/nix-community/buildbot-nix
https://tekton.dev/docs/pipelines-as-code/

## NixOS-shaped workloads: adjacent VMs, not KubeVirt

We have a path for "I want a NixOS-flavored service" at `terragrunt/modules/hcloud-nixos-server/`. Provisions a Hetzner VM, attaches it to the cluster's private network, runs `nixos-anywhere` to install from `~/Code/nixos`. Ongoing updates via `deploy-rs` (already configured upstream for `klaus`).

Considered but rejected: KubeVirt in-cluster. Two blockers, one architectural:
- No `/dev/kvm` on CPX workers. Hetzner's shared-vCPU line doesn't expose nested virt. Confirmed by checking the worker.
- CCX13 to fix would cost €16/mo always-on. Hetzner bills stopped servers at full rate, so the only way to avoid the floor is destroy/recreate cycles, which is operationally painful.
- Operator weight not justified for personal-volume use. KubeVirt earns its keep when you have several VMs that benefit from k8s-native scheduling, live migration, and shared networking. With one or two NixOS services and no migration needs, it pays infrastructure cost for capability we wouldn't exercise.

Division of labor for the adjacent-VM pattern:
- `terragrunt/` owns the Hetzner side (hcloud_server, public IP, private network attach, firewall).
- `~/Code/nixos` owns the NixOS side (`hosts/nixos/<workload>/`, services, sops, disko, deploy-rs).

Revisit KubeVirt if (a) we add a CCX worker for unrelated reasons, (b) the NixOS workload count grows past ~3, and (c) any of them actually benefit from kubectl-native VM lifecycle. None of those is true today.

## Cluster Autoscaler on Talos

Out of scope for now, but the design is sketched. To make this work later:

- Pre-generate a worker MachineConfig once via the talos provider; it's idempotent for workers and the same blob joins any number of nodes.
- Stash it as a Secret available to the Cluster Autoscaler config (large, sensitive — contains cluster CA + machine CA bootstrap material).
- Configure `cluster-autoscaler-hetzner` with one or more node groups, each pointing at: the existing Talos image ID (from the upload script), the worker MachineConfig as `cloud-init` user-data, a Hetzner network ID, location, server type, and min/max bounds.
- New VMs boot with the embedded MachineConfig, Talos applies it, kubelet joins via the same flow as a manually-provisioned worker.
- Failure mode is "delete and recreate" (no shell on Talos for retry) — keep `max-node-provision-time` low and `unremovable-node-recheck-timeout` aggressive.
- Image pipeline is the gotcha: any drift between the cluster's running Talos version and the autoscaler's `image` field results in new nodes joining at a different Talos version. Bump them in lockstep.

If we ever need this in earnest, consider Cluster API Provider Hetzner instead — it absorbs more of the bootstrap mechanics but adds its own operator footprint.

## Cluster API Provider

## Renovate

## External Secrets Operator/Provider

## Cilium

### Expose the Hubble UI

Hubble relay + UI are already enabled in the Cilium chart values (`hubble.relay.enabled`, `hubble.ui.enabled`) but the UI Service is ClusterIP-only. Add an HTTPRoute attaching to the public Gateway (or a separate auth-gated Gateway) so it's reachable at `hubble.<domain>`. Probably wants OIDC auth in front since Hubble exposes full L7 flow data; easiest is to put it behind oauth2-proxy backed by authentik, similar to how Argo CD is wired.

### Cilium not enforcing `allowedRoutes.namespaces.from: Same` on Gateway listeners

The public Gateway's HTTP listener has `allowedRoutes.namespaces.from: Same` so only the in-namespace `https-redirect` HTTPRoute can attach. Cilium honors this in the listener's `attachedRoutes` count, but at runtime it still routes per-hostname matches from HTTPS-pinned routes to port 80, defeating the redirect. Every app HTTPRoute therefore pins explicitly to `sectionName: https`. File/track upstream; once `from: Same` is enforced for real, the `sectionName` annotations can be dropped.

### HTTPRoute / Service ordering against Cilium: TEMPORARY workaround

Treat the current per-module `terraform_data.wait_for_*_svc` pattern as a stopgap, not a long-term answer.

Cilium's gatewayAPI controller resolves HTTPRoute `backendRefs` at create time and the Service watcher doesn't reliably re-reconcile when the Service appears later. Right now each service module (`services/oauth2-proxy`, `services/woodpecker`, …) has a `local-exec` block that polls `kubectl get svc` before the HTTPRoute is applied. Each new service needs the same boilerplate, which isn't sustainable.

Better landing spots to evaluate:

- HTTPRoute owned by the chart, not Terraform. When the chart applies its own HTTPRoute alongside the Service, Argo's sync ordering puts the Service first and the race goes away. Forgejo already works this way via `gateway.routes` in chart values; do the same for Woodpecker (chart supports it) and inline-render an HTTPRoute manifest into the oauth2-proxy chart's `extraManifests`.
- Confirm/file the upstream Cilium bug. The Service-watch re-reconcile failure is the actual defect. Search Cilium issues for "HTTPRoute ResolvedRefs Service not found", attach a minimal repro if no matching ticket exists, then track the fix version and drop the waits when we land on it.
- Move to a controller that handles ext_authz / per-route filters natively (Envoy Gateway, Traefik), covered separately in the "shared oauth2-proxy via CiliumEnvoyConfig" thread; same migration could eliminate this class of race entirely.

When bumping `cilium_chart_version`, re-check the race; if a freshly applied HTTPRoute reliably resolves its Service after the chart finishes rolling out, delete every `wait_for_*_svc` block.
