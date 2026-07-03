# Crossplane Migration Plan

Status: **Draft / proposal** — not yet started.
Scope: `tiborpilz/infrastructure` (Talos on Hetzner + Proxmox, ArgoCD app-of-apps).
Audience: single operator, homelab risk tolerance, production-like discipline (this runs personal git, registry, and identity).

## 1. Goal

Replace the fragile, imperative, out-of-GitOps glue in this repo with declarative,
continuously-reconciled configuration, and collapse the copy-pasted per-service
boilerplate into a single reusable abstraction. Crossplane is the right tool for
*part* of this — but not all of it. A guiding principle of this plan is: **only
use Crossplane where there is real runtime dataflow or a many-instance
abstraction. Everything else uses tools already in the repo** (`sops-secrets-operator`,
plain ArgoCD manifests, Authentik Blueprints).

## 2. What we are (and aren't) migrating

### In scope
1. **The imperative Terraform → Kubernetes glue** in
   `terragrunt/cluster/talos/main.tf:326-430` (authentik/cluster-autoscaler secrets,
   configmap, Cilium LB pool). Most of this does **not** need Crossplane — see §5, Phase 1.
2. **A `WebService` composition** to replace the per-service boilerplate
   (namespace + HTTPRoute + optional CNPG Cluster + optional oauth2-proxy + optional
   Authentik OIDC wiring), repeated across 8+ services today.
3. **The imperative OIDC bootstrap Jobs** — Harbor's `services/harbor/oidc-config.yaml`
   (curls Harbor's API) and Woodpecker's `services/woodpecker/oauth-bootstrap.yaml`
   (creates an OAuth app in Forgejo) — reconciled via `provider-http`.
4. **(Optional, last) Cloudflare wildcard DNS** consolidation.

### Explicitly out of scope (stays in Terraform/Terragrunt)
- **Talos cluster bootstrap** (machine secrets/config/bootstrap): chicken-and-egg —
  Crossplane needs a running cluster — and the Talos provider story in Crossplane is immature.
- **hcloud servers/network/floating IP** and **Proxmox VMs**: the maintained Crossplane
  Hetzner providers are single-maintainer `v0.x` hobby projects (`miaits/provider-hetzner`
  v0.2.0, Apr 2026); the Proxmox value here is the custom drain/untaint destroy-time
  scripting Crossplane wouldn't replicate. Migrating buys risk, not leverage.
- **Per-node DNS A records** (`<node>.kube.tibor.sh`): derived from TF-known server IPs;
  keep them with the servers.

## 3. Tooling decisions (grounded in mid-2026 ecosystem reality)

| Concern | Decision | Why |
|---|---|---|
| Crossplane version | **v2.3.x**, namespaced XRs, **no Claims**, Pipeline compositions | v2 is GA; Claims are gone for v2-style XRs; native patch-and-transform removed. Build new, not legacy. |
| Composition engine | `function-patch-and-transform` + `function-auto-ready`; reach for `function-go-templating` where loops/conditionals are needed | P&T-as-function is the least-surprise default; go-templating for the toggle-heavy `WebService`. |
| In-cluster objects (Object wrapper) | **`provider-kubernetes` v1.2.x** (`xpkg.crossplane.io/crossplane-contrib/provider-kubernetes`) | Mature, most-used contrib provider; `Object` + `managementPolicies: [Observe]` lets us adopt existing objects without recreating. |
| External API calls (Harbor/Forgejo OIDC) | **`provider-http` v1.0.x** (`Request` for lifecycle, idempotent via observe GET) | Harbor `PUT /api/v2.0/configurations` and Forgejo OAuth-app APIs are idempotent — a good fit. Bus factor is the risk, not code quality. |
| Cloudflare DNS | **`wildbitca/provider-upjet-cloudflare` v0.2.x, pinned** — *optional, deferred* | Official/contrib Cloudflare providers are archived or release-less. wildbitca works but is `v0.x`/single-maintainer. external-dns already covers app records; only the wildcard is a candidate. |
| Hetzner / Authentik / Forgejo providers | **Do NOT adopt** | hcloud providers immature; Authentik Crossplane providers dormant (last real release 2023); no maintained Forgejo/Gitea upjet provider. Use Authentik **Blueprints** (already in repo) and `provider-http`. |
| Credentials into providers | `ClusterProviderConfig` → `secretRef` → plain Secret materialized by **`sops-secrets-operator`** (already in repo) | ProviderConfig reads a plain Secret; sops-secrets-operator produces one from an encrypted `SopsSecret`. No new secret tooling. |
| Secret creation that has **no** dataflow | **`sops-secrets-operator`, not Crossplane** | Creating a Secret from known values is exactly what the operator already does. Crossplane would be overkill. |

**Honest note on scope creep:** kro (in-cluster composition) is still pre-1.0 / "not
production ready" and is not chosen. external-secrets-operator is not added — the repo's
`sops-secrets-operator` already fills the secret-sync role.

## 4. Target architecture

### Where Crossplane runs / ArgoCD placement
The app-of-apps tiers today are `operators (wave 0) → storage (1) → identity (2) → services (3)`.

- Crossplane core + providers + functions install as a **new app in the `operators` tier**,
  but must be **ordered before** anything that defines XRDs/Compositions/XRs. Use ArgoCD
  sync-waves *within* the operators tier:
  - wave `-5`: `sops-secrets-operator` (must exist first; it already does) + `SopsSecret`s holding provider credentials.
  - wave `-4`: Crossplane core Helm chart (`https://charts.crossplane.io/stable`) into `crossplane-system`, `ServerSideApply=true`.
  - wave `-3`: `Provider` / `Function` packages (`pkg.crossplane.io/v1`).
  - wave `-2`: `ClusterProviderConfig`s (needs provider CRDs to exist → add `SkipDryRunOnMissingResource=true`).
  - wave `-1`: XRDs + Compositions.
  - services tier: the `WebService` XRs themselves, one per app.

### Required ArgoCD configuration (known gotchas)
- `application.resourceTrackingMethod: annotation` in `argocd-cm` (Crossplane copies labels onto MRs, breaking label tracking).
- Custom Lua health checks for `*.crossplane.io/*` and `*.upbound.io/*` resources (ship the official snippets; ArgoCD's built-ins lagged v2 — CompositionRevisions stuck "Progressing").
- `resource.exclusions` for `ProviderConfigUsage` (UI/API load).
- `ARGOCD_K8S_CLIENT_QPS=300` (hundreds of provider CRDs otherwise throttle ArgoCD).
- `Prune=false` on the provider/XRD apps; use the `resources-finalizer` deliberately so deleting an app can't cascade-delete cloud resources.

### Credential flow
```
git (SopsSecret, encrypted)  →  sops-secrets-operator  →  plain Secret in crossplane-system
   →  ClusterProviderConfig.secretRef  →  provider (kubernetes / http / cloudflare)
```
This reuses the existing `age-keys` secret path. No secret ever lands in git unencrypted.

### `WebService` XRD sketch (the centerpiece)
Namespaced XR, API group `platform.tibor.sh/v1alpha1`, kind `WebService`. One XR per app,
living in the app's namespace. Composition pipeline: `function-go-templating` (toggle logic)
→ `function-auto-ready`.

```yaml
apiVersion: platform.tibor.sh/v1alpha1
kind: WebService
metadata: { name: forgejo, namespace: forgejo }
spec:
  hostname: git.tibor.sh          # HTTPRoute host
  backend:
    service: forgejo              # Service name in this namespace
    port: 3000
  database:                       # optional → renders a CNPG Cluster
    enabled: true
    name: forgejo
    size: 10Gi
    storageClass: hcloud-volumes
  oidc:                           # optional → Authentik blueprint + client secret wiring
    enabled: true
    clientId: forgejo
    redirectUris: ["https://git.tibor.sh/user/oauth2/authentik/callback"]
  authProxy:                      # optional → oauth2-proxy Application-equivalent (mutually exclusive with app-native oidc)
    enabled: false
    upstream: ""
```

Composed resources (all toggled): `Namespace`, `HTTPRoute` → the shared `public` Gateway
in `gateway-system`, `postgresql.cnpg.io/Cluster`, an `oauth2-proxy` Deployment/Service (or
a `helm.crossplane.io/Release` if we keep the chart), and — for `oidc.enabled` — the
Authentik blueprint ConfigMap fragment plus the reflector-annotated client secret.

**Deliberately left OUT of the XRD** (kept as per-app manifests): the Helm `Application` for
the app itself (charts vary too much), PVCs with immutable specs, and anything the app's own
chart already renders (e.g. forgejo's chart renders its own HTTPRoute — see open questions).

## 5. Phased migration

Each phase is independently shippable and independently revertible. **Ship one, live with
it for a few days, then proceed.**

### Phase 0 — Install Crossplane, prove the machinery (no ownership moves)
- **Goal:** Crossplane core + `provider-kubernetes` + functions healthy in ArgoCD, credentials
  flowing from a `SopsSecret`. Zero existing resources touched.
- **Steps:** add `applications/operators/crossplane/` (Helm app + `Provider`/`Function`
  packages + a `ClusterProviderConfig` for `provider-kubernetes` using the in-cluster SA).
  Apply the ArgoCD config from §4. Prove with a throwaway `Object` that manages a dummy
  ConfigMap in a scratch namespace.
- **Validation:** `crossplane` app Healthy in ArgoCD; `Provider`/`Function` `Installed`+`Healthy`;
  dummy `Object` reconciles; `crossplane trace` clean.
- **Rollback:** delete the crossplane apps. Nothing else references them yet.
- **What can break:** ArgoCD health-check false-positives (mitigated by the Lua overrides);
  CRD-count throttling (mitigated by QPS).
- **Effort:** ~0.5–1 day.

### Phase 1 — De-imperative-ize the TF glue (mostly WITHOUT Crossplane)
This is the highest-value cleanup and the honest core of the "migration": most of the
`local-exec` glue is plain secret/object creation that does **not** need Crossplane.

- **1a. Secrets → `sops-secrets-operator` (no Crossplane).** Move these out of
  `terraform_data.app_secrets` (`main.tf:326-378`) and
  `terraform_data.cluster_autoscaler_bootstrap` (`main.tf:380-415`) into committed
  `SopsSecret`s:
  - `authentik-bootstrap`, `authentik-valkey`, `authentik-oidc-clients` (ns `authentik`,
    incl. the reflector annotations mirroring `ARGOCD_OIDC_CLIENT_SECRET` → ns `argocd`).
  - `cluster-autoscaler-hcloud` (`HCLOUD_TOKEN` + `HCLOUD_CLOUD_INIT`) (ns `cluster-autoscaler`).
  - **Password provenance:** these values currently come from TF `random_password`
    (`main.tf:311-324`). Extract the *live* values from the running cluster
    (`kubectl get secret -o yaml`), re-encrypt them into the `SopsSecret`s, and commit —
    do **not** regenerate, or you'll invalidate authentik's key / autoscaler token.
- **1b. Non-secret objects → `provider-kubernetes` `Object` OR plain manifests.** The
  `cluster-autoscaler-config` ConfigMap (`HCLOUD_IMAGE/NETWORK/FIREWALL`) and the
  `CiliumLoadBalancerIPPool` (`scripts/apply-cilium-lb-pool.sh`) depend on TF module
  outputs (image/network/firewall IDs, floating IP). If those IDs are stable, commit them
  as **plain ArgoCD manifests** (simplest). Use a Crossplane `Object` only if you want the
  value sourced from live cluster state rather than pinned. *Recommendation: plain manifests;
  revisit `Object` only if the IDs churn.*
- **Handoff (critical, avoids TF ↔ GitOps fights):** for each item, first let GitOps
  create/adopt it, confirm it's identical, **then** delete the `terraform_data` block and
  `terraform state rm` it. The k8s objects were made by `kubectl apply` and are not in TF
  state as real resources, so removing the block won't delete them. Order: create in GitOps →
  verify → remove TF block → run `terragrunt plan` and confirm **no** recreation is proposed.
- **Validation:** authentik pods still start with the same secret; cluster-autoscaler still
  scales (test by cordoning to force a scale event, or inspect its logs for auth success);
  LB pool still advertises the floating IP; `terragrunt plan` is clean.
- **Rollback:** re-add the `terraform_data` block and `terragrunt apply` (idempotent
  `kubectl apply`). Keep the block in git history for one release cycle.
- **What can break:** the **cluster-autoscaler credential** is load-bearing — a wrong token
  means no new nodes. Do this item last within Phase 1 and during a low-churn window.
  Regenerating the authentik secret key would break existing sessions/tokens.
- **Effort:** ~1–2 days. (Note: this phase alone removes the most fragile code and could be
  shipped even if the rest of the plan is abandoned.)

### Phase 2 — `WebService` composition, adopt the simplest service
- **Goal:** XRD + Composition live; migrate **headlamp** first (oauth2-proxy + HTTPRoute,
  **no database** → lowest blast radius).
- **Steps:** define the XRD/Composition (§4). Author `WebService/headlamp`. Use
  `managementPolicies: [Observe]` on composed `Object`s first to confirm the render matches
  the existing `headlamp.tibor.sh` HTTPRoute + oauth2-proxy, then switch to full management
  and delete the hand-written manifests (`services/headlamp/*`).
- **Validation:** `crossplane render` + `crossplane beta validate` in CI produce the same
  objects that exist now; `headlamp.tibor.sh` stays up through the cutover; ArgoCD diff is empty
  after adoption.
- **Rollback:** re-apply the old `services/headlamp/` manifests; delete the XR (with
  `Orphan`/Observe first so it doesn't tear down the live route).
- **What can break:** field-manager conflicts between the old ArgoCD-applied objects and the
  Crossplane-applied ones — that's exactly why we adopt via Observe before taking over.
- **Effort:** ~2–3 days (most of it is the XRD/Composition, amortized across later services).

### Phase 3 — Extend `WebService` to database-backed services
- **Goal:** onboard forgejo, harbor, woodpecker; XR renders their CNPG `Cluster`.
- **CNPG immutability trap (call-out):** CNPG `Cluster` storage and PVC specs are immutable —
  the repo already hit this (`harbor-db` → `harbor-pg` rename churn). You **cannot** simply
  re-parent a live DB under the composition if any immutable field would change. Two safe
  options per DB: (a) match the existing spec exactly and adopt via `Observe`; or (b) leave the
  existing `Cluster` as a hand-written manifest and have `WebService` reference it rather than
  own it. **Default to (b) for already-live DBs**; only newly-created DBs are born under the composition.
- **Validation / rollback / breakage:** as Phase 2, per service. Never let a composition change
  propose deleting a live `Cluster` — guard with `deletionPolicy: Orphan` on DB objects.
- **Effort:** ~1 day per service after the pattern is set.

### Phase 4 — Replace imperative OIDC Jobs with `provider-http`
- **Goal:** delete `services/harbor/oidc-config.yaml` (Job) and
  `services/woodpecker/oauth-bootstrap.yaml` (Job + cross-ns RBAC), replacing them with
  `provider-http` `Request`s.
  - Harbor: `Request` → `PUT /api/v2.0/configurations` (auth_mode=oidc_auth, groups_claim,
    admin_group) with an observe `GET` for idempotency; admin creds from a `SopsSecret`.
  - Woodpecker↔Forgejo: `Request` → Forgejo's OAuth-app API to create/observe the app; write the
    client id/secret back into `woodpecker-oauth`.
- **Validation:** Harbor OIDC login works; the `Request` reports up-to-date on re-reconcile
  (not re-firing); Woodpecker can log in via Forgejo.
- **Rollback:** re-add the Jobs (kept in git history); they're idempotent.
- **What can break:** provider-http observe/`isUpToDate` mapping mis-specified → constant
  re-fire or false drift. Test the observe GET carefully.
- **Effort:** ~1–2 days (provider-http learning curve is the cost).

### Phase 5 — (Optional) Cloudflare wildcard DNS
- **Goal:** move the `*.tibor.sh` wildcard A record (`terragrunt/cluster/dns/main.tf:14-22`)
  to a Crossplane `Record` (wildbitca provider) or a static external-dns `DNSEndpoint`.
- **Recommendation:** **defer / probably skip.** external-dns already reconciles app records; a
  single static wildcard is trivial in TF and the wildbitca provider is `v0.x`/single-maintainer.
  Only worth it if you want *all* DNS under one reconciler. Per-node records stay in TF regardless.
- **Effort:** ~1 day if pursued.

## 6. Risks & mitigations (cross-cutting)
- **Provider abandonment (Cloudflare/http):** pin exact versions; keep the Terraform/Job
  fallback in git history; avoid putting cluster-critical infra behind `v0.x` providers.
- **ArgoCD ↔ Crossplane health/pruning deadlocks:** ship the Lua health overrides; `Prune=false`
  and explicit finalizers on provider/XRD apps.
- **TF ↔ Crossplane double-ownership:** every handoff is "adopt via Observe → verify → remove TF
  → confirm clean plan." Never delete-and-recreate load-bearing objects.
- **Secret regeneration:** extract and re-encrypt *live* secret values; never regenerate
  authentik's key or the hcloud token during migration.
- **Blast radius:** authentik (identity for everything), argocd (the deployer itself), and DNS
  are never mid-cutover simultaneously; migrate leaf services before shared infra.

## 7. Open questions (resolve before/during the relevant phase)
- **forgejo-oidc duplication:** the secret appears both as a reflection source in ns `authentik`
  (`identity/authentik/secrets.enc.yaml`) and as a consumer in ns `forgejo`
  (`services/forgejo/secrets.enc.yaml`). Confirm which is canonical before the `WebService` OIDC toggle owns it.
- **tekton has no blueprint** despite its oauth2-proxy referencing `.../o/tekton/`, and no
  `TEKTON_OIDC_CLIENT_SECRET` in authentik's `global.env`. Is the tekton Authentik app created
  manually? The `WebService` OIDC path should formalize this gap, not inherit it.
- **Gateway `ssh` listener:** `tangled/knot/tcproute-ssh.yaml` targets Gateway `public`
  `sectionName: ssh`, but the bootstrap Gateway (`gateway.tf`) only defines http/https. Locate
  the ssh listener before modeling tangled in `WebService` (tangled may stay hand-written).
- **forgejo's chart renders its own HTTPRoute** — decide whether `WebService` owns the route or
  the chart does, to avoid two owners of `git.tibor.sh`.
- **Two secret backends** (`SopsSecret` vs ksops kustomize generator) coexist. The `WebService`
  OIDC secret wiring should standardize on one; `SopsSecret` is the better fit for reflector annotations.

## 8. Sequencing summary & total effort
Phase 0 (0.5–1d) → Phase 1 (1–2d, highest value, shippable alone) → Phase 2 (2–3d, builds the
composition) → Phase 3 (~1d/service) → Phase 4 (1–2d) → Phase 5 (optional, defer).
**Rough total for Phases 0–4: ~2 weeks of focused evenings**, front-loaded on the composition.

**Stop-and-reassess gates:** after Phase 1 (is the reconciled glue actually less painful than
the old local-exec?) and after Phase 2 (does the `WebService` abstraction pay for its complexity
across ≥3 services, or is a kustomize component / Helm library chart simpler for this many
instances?). If either gate fails, stop — Phase 1's cleanup stands on its own.

---
*This plan intentionally keeps Crossplane's footprint minimal: it earns its place only for the
`WebService` composition (Phases 2–3) and the `provider-http` API reconciliation (Phase 4).
The secret/glue cleanup (Phase 1) uses tools already in the repo.*
