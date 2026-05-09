# `argocd` module — bootstrap layer

Brings the cluster from "kube-apiserver running, no networking" to "GitOps control plane ready". Order:

1. **kubernetes_secret.hcloud** — Hetzner token + network ID for the CCM.
2. **helm_release.cilium** — CNI + kube-proxy replacement + Hubble + Gateway API. Pods can now schedule.
3. **helm_release.hcloud_ccm** — Hetzner CCM. Removes the `node.cloudprovider.kubernetes.io/uninitialized` taint, populates node external IPs, sets up routes for the private network.
4. **kubernetes_namespace.argocd** — namespace.
5. **helm_release.argocd** — Argo CD itself, plus three AppProjects (`platform`, `projects`, `sandbox`) inlined via `extraObjects`.

After this layer applies, `kubectl get nodes` shows `Ready` and Argo CD is reachable in-cluster at `argocd-server.argocd.svc.cluster.local`.

## Why this layer does so much

PLAN.md positions `20-argocd` as "install the GitOps control plane". In practice, Argo CD has a chicken-and-egg dependency on the cluster being functional — and that requires Cilium (CNI) and the Hetzner CCM (taint removal). So this layer is the **bootstrap**: everything required for any GitOps-managed app to ever schedule.

`30-networking` (next) creates `argocd_application` resources for cert-manager and external-dns. Cilium and CCM stay TF-managed for now (bootstrap exception); we may fold them into Argo's inventory in a later milestone.

## What this layer does NOT do

- No DNS records or TLS certs yet — that's `30-networking`.
- No Argo CD ingress / Gateway HTTPRoute. Reach the UI via `kubectl port-forward` for M1.
- No OIDC for Argo CD. Default admin password from the chart; rotate or replace in M2 with Authentik.
- No CSI driver. Argo CD doesn't need PVs and we have no stateful workloads yet. Add hcloud-csi when M2 introduces stateful apps.

## Inputs

See `variables.tf`. Required: `kubernetes_host`, `cluster_ca_certificate`, `client_certificate`, `client_key`, `hcloud_token`, `hcloud_network_id`.

Chart versions are pinned via defaults; bump as needed.

## Outputs

Just chart versions and the Argo CD namespace name. No sensitive data — kubeconfig + talosconfig already live on disk from 10-cluster.

## Reaching Argo CD UI (M1)

```bash
KUBECONFIG=.kube/hcloud-poc.kubeconfig kubectl -n argocd port-forward svc/argocd-server 8080:443
# admin password:
KUBECONFIG=.kube/hcloud-poc.kubeconfig kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

Then https://localhost:8080, user `admin`, password from the Secret. Replace this in M2 with OIDC + a real route.

## Notes

- **Chart `wait` semantics**: every `helm_release` here has `timeout = 300` or `600`. The provider waits for resources to become Ready before declaring the release applied. CCM in particular needs to remove the uninitialized taint before its pods are considered Ready.
- **`extraObjects` for AppProjects**: avoids the `kubernetes_manifest` plan-time CRD lookup problem. The Helm chart applies them after Argo CD CRDs are installed.
- **No `kubernetes_manifest`**: deliberately avoided. Use `extraObjects` in Helm releases or a separate `argocd_application` provider for downstream layers.
