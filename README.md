# Infrastructure

Scaffoldable Kubernetes platform on Hetzner. See [`PLAN.md`](./PLAN.md) for the full design rationale, constraints, and milestone roadmap.

## Layers

The `terragrunt/envs/<env>/` directory contains the layered Terragrunt stacks. Apply order is enforced by `dependency` blocks; `terragrunt run --all apply` walks the graph correctly.

| Layer | Purpose |
| --- | --- |
| `00-machines` | Hetzner network + VMs. Outputs a generic node inventory. |
| `10-cluster` | Talos config + bootstrap. Outputs kubeconfig material. |
| `20-argocd` | Cilium (CNI + Gateway API), Hetzner CCM, Argo CD, AppProjects. |
| `30-networking` | cert-manager, external-dns, public Gateway. |
| `30-smoke-app` | Trivial nginx behind the Gateway. End-to-end TLS/DNS proof. |
| `35-platform-data` | hcloud-csi (`hcloud-volumes` StorageClass) + CloudNativePG operator. |
| `40-authentik` | authentik (OIDC provider) + CNPG `Cluster` + inlined Valkey. |
| `45-authentik-config` | General authentik state — placeholder groups. No per-app clients. |

## Per-app identity convention

When a future module deploys a core app that consumes authentik OIDC, it owns BOTH the app's deployment and its authentik client config. Layout inside the module:

```hcl
# random_password lives in TF state; never in Git
resource "random_password" "oidc_client_secret" {
  length  = 48
  special = false
}

resource "authentik_provider_oauth2" "this" {
  name           = "<app>"
  client_id      = "<app>"
  client_secret  = random_password.oidc_client_secret.result
  redirect_uris  = [{ matching_mode = "strict", url = "https://<app>.<domain>/oauth/callback" }]
  authorization_flow = data.authentik_flow.default_authorization.id
  authentication_flow = data.authentik_flow.default_authentication.id
}

resource "authentik_application" "this" {
  name              = "<app>"
  slug              = "<app>"
  protocol_provider = authentik_provider_oauth2.this.id
}

# Consumed by the app's Helm chart via valuesObject or env
resource "kubernetes_secret" "<app>_oidc" {
  metadata {
    namespace = "<app>"
    name      = "<app>-oidc"
  }
  data = {
    client_id     = authentik_provider_oauth2.this.client_id
    client_secret = random_password.oidc_client_secret.result
    issuer_url    = "${var.authentik_url}/application/o/<app>/"
  }
}

resource "kubectl_manifest" "argo_app_<app>" {
  # Argo CD Application that references the secret above
  ...
}
```

**Why not a central `40-post-config` layer?** PLAN.md flagged that as awkward. Colocating the identity client with the consumer means adding/removing an app is one module change, the dependency graph stays local, and there's no single layer that knows about every app. Multiple core apps may share one Terragrunt env layer (e.g. `50-core-apps`) — they don't each need a dedicated layer.

**What lives in `45-authentik-config`?** Only state that isn't tied to a specific app: groups, branding, SMTP, MFA policies, default flows. The `akadmin` password is already pinned upstream by `40-authentik` (TF-generated `random_password` mounted as `AUTHENTIK_BOOTSTRAP_PASSWORD`).

## Reaching the cluster

After `terragrunt run --all apply`:

```sh
export KUBECONFIG=.kube/hcloud-poc.kubeconfig
kubectl get nodes
```

authentik bootstrap admin password (first login):

```sh
terragrunt --working-dir terragrunt/envs/hcloud-poc/40-authentik output -raw bootstrap_admin_password
```

## Local development

`shell.nix` / `flake.nix` pin the toolchain. `nix develop` (or `direnv allow`) brings in `terragrunt`, `tofu`, `talosctl`, `kubectl`, `argocd`, `helm`, etc.
