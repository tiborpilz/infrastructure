# Operations notes

Things that broke and how to fix them, plus knobs / decisions that don't live in module READMEs.

For module-level docs see:
- `terragrunt/services/omni/README.md`
- `terragrunt/services/tekton/README.md`
- `terragrunt/platform/longhorn/README.md`
- `terragrunt/modules/hcloud-nixos-server/README.md`

For roadmap + design rationale: `PLAN.md`. For deferred work: `TODO.md`.

---

## Talos upgrade recovery

`talosctl upgrade --image factory.talos.dev/installer/<schematic>:vX.Y.Z` is the canonical path. The TF cluster module sets `ignore_changes = [image]` on `hcloud_server` for exactly this — `terragrunt apply` deliberately does NOT change the Hetzner image of a running node; Talos handles the OS swap in-place via A/B partitions.

### Hostname drift after upgrade

**Symptom**: post-upgrade, `kubectl get nodes` shows two entries — the old name (`controlplane-1` or `worker-1`) as `NotReady`, and a new `talos-<random-hash>` as `Ready`. Kubelet stopped posting status to the old entry and re-registered as a new node.

**Why**: hostname is derived from a `HostnameConfig` document with `auto: hcloud` (platform metadata). Across some A/B swaps, platform metadata fails to populate and Talos falls back to the default `talos-<hash>`.

**Fix**: edit the running config to use a static hostname.

```bash
# 1. Edit interactively
talosctl --talosconfig ~/Code/infrastructure/.talos/hetzernetes.talosconfig \
  -n <node-public-ip> edit machineconfig

# Find the `kind: HostnameConfig` document, change:
#     auto: hcloud      →  hostname: controlplane-1
# (replace the `auto` line entirely with `hostname:`; can't have both)

# 2. Save + exit. When prompted, pick `reboot` apply mode.

# 3. Wait for the node to come back
kubectl get nodes -w

# 4. Uncordon (talosctl drained the node during upgrade)
kubectl uncordon <node-name>

# 5. Prune the zombie
kubectl delete node talos-<old-hash>
```

Tried codifying this in TF (push a HostnameConfig doc via `config_patches`). Doesn't work — see TODO.md entry "Talos upgrade: hostname can drift…" for details. Manual fix is the proven path.

### Image upload script

`setup/upload-talos-image.sh` is idempotent on `TALOS_EXTENSIONS`. Sets a 16-char `schematic=` label on the Hetzner snapshot derived from the first 16 hex chars of the schematic ID (Hetzner labels cap at 63 chars; full SHA256 is 64). Bumping extensions rotates the schematic, rotates the label, triggers a re-upload.

```bash
TALOS_EXTENSIONS="siderolabs/qemu-guest-agent siderolabs/iscsi-tools siderolabs/util-linux-tools" \
  ./setup/upload-talos-image.sh
```

---

## Hetzner label 64-char limit

Hetzner Cloud rejects label values longer than 63 chars or containing chars outside `[A-Za-z0-9._-]`. This bites in several places:

- **PVC names propagated to volume labels** — hcloud-csi copies the PVC name into a Hetzner label. PVC names from Helm charts can easily exceed 64 chars (e.g., `prometheus-monitoring-kube-prometheus-db-prometheus-monitoring-kube-prometheus-0`). Fix is either short release name or `fullnameOverride` in chart values.
- **Talos schematic IDs** — 64-char SHA256 hex, one over the cap. Truncate to first 16 chars.
- **Joining extension lists into a label value** — `/` from `siderolabs/iscsi-tools` is invalid; the joined string also blows past 63 chars with more than 2-3 extensions. Use the schematic ID hash instead.

When hcloud-csi rejects volume creation with "invalid input in field 'labels'", the offending value is usually the PVC name or an annotation propagated as-is.

---

## kube-prometheus-stack PVC names

`fullnameOverride: kps` is critical in `applications/kube-prometheus-stack/values.yaml.tpl`. Without it, the chart computes Prometheus/Alertmanager CR names from `<release>-<chart-name>` = `monitoring-kube-prometheus-stack`, which produces ~90-char PVC names that hcloud-csi rejects.

Other relevant knobs in that values file:
- `cleanPrometheusOperatorObjectNames: true` — strips chart prefix from operator-managed objects
- `prometheus.name` / `alertmanager.name` look like the right knob but DON'T WORK in chart v67.x — the CR name still falls through to `fullname`. `fullnameOverride` is the only effective lever.

Both Prometheus and Alertmanager CRs end up named `kps` after the override. They're different `Kind` resources so no collision; downstream StatefulSets are `prometheus-kps` and `alertmanager-kps`.

---

## Authentik

### Recovery email + invitation flow

SMTP wiring was removed (we explored Fastmail integration, decided it wasn't worth the friction). Result:
- No password recovery emails — admin sets passwords manually via Authentik UI or `kubectl exec`.
- Invitation flow exists but admin manually copies the URL to send.
- See `services/authentik-config/invitation-flow.tf` for the flow.

If recovery emails become desired later, the SMTP wiring lives at history `7475eb1`-ish (search git log for `fastmail` or `smtp`).

### OIDC client conventions

- Per-app OIDC client lives in the same TF module as the app (per `README.md` convention).
- Omni's redirect URI is `/oidc/consume`, NOT `/omni/callback`. Confirmed against Omni source.
- Grafana uses native OIDC (`auth.generic_oauth` in chart values), not oauth2-proxy. Role mapping via JMESPath: `contains(groups[*], 'platform-admins') && 'Admin' || ''` with `role_attribute_strict: true` rejects users not in platform-admins.
- Tibor is in `authentik-superusers` group for Authentik UI admin (surgical, not whole `platform-admins`).

### TF-provisioned users + `allowUnverifiedEmail`

Authentik's TF-provisioned users have no `email_verified` claim because no verification flow ran. Apps that strictly require it (Omni) reject these users with `email not verified`. Fix: set `allowUnverifiedEmail: true` on the consuming app's OIDC config. Authentik already authenticated the user upstream; bypassing the verified flag is reasonable here.

### Invited users land as `internal`

`services/authentik-config/invitation-flow.tf` sets `user_type = "internal"` on the user_write stage. Without this, new users land as `external` and get rejected from the Authentik UI itself with "Interface can only be accessed by internal users".

---

## Argo CD

### Default RBAC

`policy.default = ""` in `platform/argocd/main.tf`. Without explicit empty default, the chart applies `role:readonly` to all authenticated users — leaks Application + cluster topology to anyone who can log in via Authentik (including freshly-enrolled invitees). Only members of `platform-admins` get any access.

### Sync of charts that aren't full chart releases

For helm charts where the upstream provides a pre-rendered `release.yaml` (Tekton operator), vendor it under `applications/<name>/` and apply via `data.kubectl_file_documents` + `kubectl_manifest` for_each. Skip Argo CD for those — ArgoCD can't process `ko://` placeholders in upstream chart sources.

Tekton operator's `release.yaml` is vendored at `applications/tekton-operator/release.yaml` — refresh via:
```bash
gh release download v<X.Y.Z> -R tektoncd/operator -p release.yaml \
  -D applications/tekton-operator/ --clobber
```

### Prune deleted system ClusterRoles once

During recovery from a botched apply, some built-in `system:*` ClusterRoles got pruned by Argo. Symptom: hcloud-csi-controller failing with `clusterrole.rbac.authorization.k8s.io "system:basic-user" not found`. Fix: restart `kube-controller-manager` — its bootstrap-controller re-creates `system:*` ClusterRoles on startup.

```bash
kubectl -n kube-system delete pod -l component=kube-controller-manager
```

---

## Longhorn

### Pre-upgrade hook + ArgoCD race

The chart's `longhorn-pre-upgrade` Helm hook references the chart's `longhorn-service-account`. ArgoCD applies hooks before regular resources, so the SA doesn't exist when the hook fires — Job stuck in `FailedCreate` forever. Workaround in `applications/longhorn/values.yaml.tpl`:

```yaml
preUpgradeChecker:
  jobEnabled: false
  upgradeVersionCheck: false
```

Preflight validations still happen at DaemonSet startup so we don't lose the iscsi check — just moved out of Argo's critical path.

### Talos extension prereq

Longhorn needs `siderolabs/iscsi-tools` + `siderolabs/util-linux-tools` baked into the Talos image. Bake via factory.talos.dev, push the new image via the upload script, `talosctl upgrade --image factory.talos.dev/installer/<schematic>:vX.Y.Z` per node.

---

## Cilium

### Connection drops after node reboot

Symptom: pods fail to connect to in-cluster services with `Operation not permitted` (EPERM on TCP connect, not ECONNREFUSED). This is Cilium's eBPF datapath rejecting; usually inconsistent BPF state after a node reboot.

Fix: recycle the Cilium DaemonSet to rebuild BPF maps.

```bash
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=3m
```

### Gateway listener leak — `sectionName: https` required

Cilium's Gateway API controller doesn't fully enforce `allowedRoutes.namespaces.from: Same` on listeners. HTTPRoutes from any namespace can attach to the HTTP listener at runtime and bypass the HTTPS redirect. Every app HTTPRoute therefore pins explicitly to `sectionName: https`. See TODO.md entry "Cilium not enforcing `allowedRoutes.namespaces.from: Same`".

---

## Node sizing notes

Current: 1× `cpx32` control plane (8 GB), 1× `cpx22` worker (4 GB) as static baseline. Burst capacity on top comes from `cluster-autoscaler` (see "Cluster autoscaler" below) — pool of cpx32 workers, scales 0→3 in response to Pending pods, scales back to 0 after 5m unused.

History: with this single static worker the cluster hits ~80% memory in steady state under the full stack (Authentik + Forgejo + Woodpecker + Tekton + Omni + ArgoCD + observability + Longhorn). Authentik and Woodpecker pipeline pods OOM-killed first (exit 137) when pressure spiked. Bursty CI now lifts capacity via the autoscaler instead of running a permanently-oversized worker.

Practical mitigations applied:
- ArgoCD scheduler now places pods on the control plane too (`allowSchedulingOnControlPlanes = true`).
- Prometheus retention dropped to 5d, resources trimmed in the values file.

If Woodpecker jobs still hit 137 on specific pipelines after worker sizing, the fix is per-step memory in `.woodpecker.yml`, not more nodes:

```yaml
steps:
  build:
    image: node:20
    commands: [npm ci, npm run build]
    backend_options:
      kubernetes:
        resources:
          requests: { memory: 2Gi }
          limits:   { memory: 4Gi }
```

Woodpecker 3.x has no env var for cluster-wide default pod resources (only per-step `backend_options.kubernetes.resources` is honored — upstream feature request `woodpecker-ci/woodpecker#1303`). For a namespace-wide default, apply a Kubernetes `LimitRange` to the `woodpecker` namespace; the agent's spawned pods will inherit defaults from it.

Rebalancing pods after install storms:
```bash
kubectl drain worker-1 --ignore-daemonsets --delete-emptydir-data --disable-eviction
kubectl uncordon worker-1
# Pods reschedule; scheduler uses both nodes
```

---

## Cluster autoscaler

`terragrunt/platform/cluster-autoscaler/` deploys the upstream `cluster-autoscaler` Helm chart with the Hetzner cloud-provider. One burst pool, configured in `terragrunt/platform/terragrunt.hcl`:

```
pool_name          = "hetzernetes-burst"
pool_instance_type = "cpx32"
pool_min           = 0
pool_max           = 3
```

When unschedulable pods appear, the autoscaler dials the Hetzner API and provisions a new server from the same Talos snapshot the static workers use. Bootstrap is driven by Hetzner user-data — the generic worker MachineConfig is plumbed through:

```
cluster/talos/main.tf       → data.talos_machine_configuration.worker_template
cluster/outputs.tf          → worker_machine_config_template (sensitive)
platform/terragrunt.hcl     → reads it from dependency.cluster.outputs
platform/cluster-autoscaler → base64-encodes into Secret as HCLOUD_CLOUD_INIT
```

New nodes register, kubelet joins, scheduler places the Pending pod. When the node sits unused for 5m (`scale-down-unneeded-time`), the autoscaler decommissions it.

### Caveats

- **Talos version drift.** The autoscaler boots from `HCLOUD_IMAGE = talos_image_id`. After `talosctl upgrade --image …` on the running nodes, new autoscaled nodes still boot from the OLD snapshot until the snapshot is rebuilt (`setup/upload-talos-image.sh`) and `cluster` is re-applied. Bump in lockstep with cluster upgrades.
- **No retry on bad node.** Talos has no shell, so a half-bootstrapped node can't be debugged in-place. `max-node-provision-time: 8m` means CAS deletes and re-provisions after that timeout. If pools keep flapping, check the Talos kernel logs via Hetzner console.
- **Pool change ≠ in-place edit.** Changing `pool_instance_type` or `pool_location` in terragrunt doesn't migrate running burst nodes; they keep their original shape until they scale down. Force a fresh provision by setting `pool_max` to current count, waiting for scale-down, then restoring.
- **Hetzner LimitRange.** The Hetzner project has a server-count quota (default 10). Burst pool max + static workers + CP must fit. Lift the quota in the Hetzner console if needed.

### Observing it

```bash
kubectl -n cluster-autoscaler logs deploy/cluster-autoscaler-hetzner-cluster-autoscaler -f
kubectl get nodes -l 'hcloud/node-group=hetzernetes-burst'
```

The cluster-autoscaler logs scale-up decisions with the pending pod + simulated node-group fit. If pods stay Pending and the autoscaler logs `no node group can satisfy`, the pod requests more memory/CPU than the pool's instance type provides — bump `pool_instance_type` or the per-step `backend_options.kubernetes.resources` in `.woodpecker.yml`.

---

## Hetzner CPX vs CCX

CPX (shared vCPU) does NOT reliably expose `/dev/kvm`. Nested virtualization is only guaranteed on the CCX (dedicated vCPU) line. This rules out:
- KubeVirt (needs `/dev/kvm` on the host)
- Anything that wants real VMs on the worker nodes

The chosen alternative for NixOS-shaped workloads: adjacent Hetzner VMs via `terragrunt/modules/hcloud-nixos-server/`. No nested virt needed; cheaper (CX22 ~€4.50/mo per workload vs CCX13 ~€16/mo always-on for KubeVirt host).

---

## PVC orphan cleanup

When a chart's release name or release version changes, old PVCs become orphans (Pending, nothing binding to them, blocking new ones). Just delete them:

```bash
kubectl -n <ns> get pvc
kubectl -n <ns> delete pvc <orphan-name>
```

Common when:
- Changing Helm `releaseName` (PVC name pattern includes release)
- Changing Helm `fullnameOverride`
- Operator-managed PVCs (Prometheus, CNPG) when the CR is renamed/recreated

---

## Woodpecker

### `.woodpecker.yml` and manual triggers

Manual triggers from the Woodpecker UI fire with `event: manual`. If your `when:` block doesn't list `manual`, the pipeline is silently skipped (looks like nothing happened):

```yaml
when:
  - event: push
    branch: main
  - event: pull_request
  - event: manual          # ← required for the "Run pipeline" button
```

### `GetContentsOrList` log noise

Woodpecker logs `error: GetContentsOrList` when checking the `.woodpecker/` *folder* path — even when the actual `.woodpecker.yml` file is found and the pipeline runs fine. Upstream papercut; cosmetic.
