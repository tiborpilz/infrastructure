# TODO

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

## Cluster API Provider

## Renovate

## External Secrets Operator/Provider

## Cilium

### Expose the Hubble UI

Hubble relay + UI are already enabled in the Cilium chart values (`hubble.relay.enabled`, `hubble.ui.enabled`) but the UI Service is ClusterIP-only. Add an HTTPRoute attaching to the public Gateway (or a separate auth-gated Gateway) so it's reachable at `hubble.<domain>`. Probably wants OIDC auth in front since Hubble exposes full L7 flow data; easiest is to put it behind oauth2-proxy backed by authentik, similar to how Argo CD is wired.

### HTTPRoute / Service ordering against Cilium — TEMPORARY workaround

Treat the current per-module `terraform_data.wait_for_*_svc` pattern as a stopgap, not a long-term answer.

Cilium's gatewayAPI controller resolves HTTPRoute `backendRefs` at create time and the Service watcher doesn't reliably re-reconcile when the Service appears later. Right now each service module (`services/oauth2-proxy`, `services/woodpecker`, …) has a `local-exec` block that polls `kubectl get svc` before the HTTPRoute is applied. Each new service needs the same boilerplate, which isn't sustainable.

Better landing spots to evaluate:

- HTTPRoute owned by the chart, not Terraform. When the chart applies its own HTTPRoute alongside the Service, Argo's sync ordering puts the Service first and the race goes away. Forgejo already works this way via `gateway.routes` in chart values; do the same for Woodpecker (chart supports it) and inline-render an HTTPRoute manifest into the oauth2-proxy chart's `extraManifests`.
- Confirm/file the upstream Cilium bug. The Service-watch re-reconcile failure is the actual defect. Search Cilium issues for "HTTPRoute ResolvedRefs Service not found", attach a minimal repro if no matching ticket exists, then track the fix version and drop the waits when we land on it.
- Move to a controller that handles ext_authz / per-route filters natively (Envoy Gateway, Traefik), covered separately in the "shared oauth2-proxy via CiliumEnvoyConfig" thread; same migration could eliminate this class of race entirely.

When bumping `cilium_chart_version`, re-check the race; if a freshly applied HTTPRoute reliably resolves its Service after the chart finishes rolling out, delete every `wait_for_*_svc` block.
