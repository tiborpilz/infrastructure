# Scaffoldable Kubernetes Platform on Hetzner / Generic Machines

## Goal

Build a small, scaffoldable Kubernetes platform for a group of friends working on side projects.

The platform should provide:

- Kubernetes cluster bootstrap
- GitOps deployment
- Git hosting
- CI
- container image registry
- central identity / OIDC
- ingress and TLS
- basic observability
- a clean path from single-node PoC to multi-node HA
- a clean separation between core platform apps and later project apps

The first implementation target is Hetzner Cloud. The design should avoid coupling the upper layers too tightly to Hetzner so that a later Raspberry Pi / bare metal / static-machine target remains possible.

## Constraints

### Cost target

PoC ceiling: €50-70/month total cloud spend.

This covers single-node sizing (1×16 GB Hetzner VM, one Hetzner LoadBalancer, Hetzner Object Storage for backups, miscellaneous storage and traffic).

HA migration is explicitly out of this budget. Moving to 3×8 GB or 3×16 GB control plane will roughly double or triple node cost and is a separate budget conversation.

### Idempotent re-apply

`terragrunt run --all apply` against an existing cluster must be safe. No half-applied state, no manual cleanup between runs, no resource recreation churn. This is a hard requirement for the bootstrap design.

## Current repository context

The existing stack already uses:

- Hetzner Cloud
- Terraform / Terragrunt
- Kubernetes
- Argo CD
- a split between infrastructure provisioning and application manifests
- git-crypt for filtering/encrypting secrets

The current repository already has the right broad shape: Terragrunt for infrastructure and Argo CD for application deployment.

The new design should preserve the good parts:

- Terragrunt as orchestration/state boundary
- Argo CD as Kubernetes reconciler
- application manifests in Git
- staged deployment
- possibility of one-command bootstrap

But it should remove or improve the awkward parts:

- RKE1 dependency
- Terraform applying arbitrary unknown CRD resources
- unclear split between cluster bootstrap and app bootstrap
- overly implicit waits between GitOps reconciliation and Terraform post-configuration
- secrets managed through repository-wide transparent encryption

## Desired user experience

A single command:

```bash
terragrunt run --all apply --working-dir terragrunt/envs/hcloud-poc
```

Terragrunt's `dependencies` graph orders the layers. Readiness waits between layers are encoded as `terraform_data` resources with `local-exec` provisioners, living inside the modules they belong to. No wrapper shell script.

The Terragrunt runner needs `kubectl` and `argocd` CLI on `$PATH`. Document this in the README.

A wrapper script may be added later for nicer first-run UX (preflight checks, friendly progress output), but it must not be load-bearing — `terragrunt apply` alone must produce a working cluster.

## Layer model

### 00-machines

Purpose: produce machines and a generic node inventory.

This layer is provider-specific.

For Hetzner it creates:

- Hetzner network
- subnets
- firewalls
- placement groups if needed
- load balancer primitives if managed outside Kubernetes
- VMs
- base DNS records if needed
- machine metadata outputs

For a static/bare-metal/Raspberry Pi target, this layer may not create machines at all. It may only output a static node inventory.

Output contract:

```hcl
nodes = {
  control_plane = {
    cp-1 = {
      name         = "cp-1"
      ipv4         = "10.0.0.11"
      public_ipv4  = "203.0.113.11"
      install_disk = "/dev/sda"
      arch         = "amd64"
      provider_id  = "hcloud://123456"
    }
  }

  workers = {}
}
```

Use maps and `for_each`, not positional `count`, to avoid accidental recreation when adding/removing nodes.

### 10-cluster

Purpose: turn machines into Kubernetes.

Recommended default: Talos.

This layer consumes the generic node inventory and outputs:

- kubeconfig
- cluster endpoint
- Talos config / machine config outputs if needed
- break-glass admin access material
- node metadata

Responsibilities:

- generate Talos machine configs
- apply Talos configs
- bootstrap the first control-plane node once
- join additional control-plane/worker nodes
- configure kube-apiserver OIDC flags if enabled
- keep cert-based admin access as break-glass auth

Initial size recommendation:

```text
PoC:
  1x 16 GB node

HA later:
  3x 8 GB or 3x 16 GB nodes
```

If non-HA is acceptable, start with `1x16 GB` rather than `3x8 GB`. One 16 GB node has less fixed Kubernetes/node overhead and less memory fragmentation. Three 8 GB nodes are useful when testing HA, but each node pays fixed overhead for kubelet, CNI, CSI, DaemonSets, and control-plane components.

Scaling up:

- `1 control-plane → 3 control-plane` should be supported.
- Add new node entries in `00-machines`.
- `10-cluster` applies configs and joins them.
- Do not re-bootstrap the cluster.

Scaling down:

- Worker scale-down can be supported with drain/delete workflow.
- Control-plane scale-down is sensitive because of etcd quorum and should require an explicit workflow.
- Avoid changing node names/private IPs.

### 20-argocd

Purpose: install GitOps control plane.

Responsibilities:

- install Argo CD
- configure repositories
- configure initial admin/OIDC later
- create AppProjects
- optionally create Terraform-managed Argo CD Applications for core apps

Argo CD should not be installed by Argo CD itself initially. Terraform/Terragrunt should bootstrap it.

### 30-core-apps

Purpose: define the platform’s core application inventory.

Terraform/Terragrunt owns the list of core Argo CD Applications. Argo CD owns the Kubernetes resources rendered by each Application.

Terraform manages:

- `argocd_application.identity`
- `argocd_application.forgejo`
- `argocd_application.woodpecker`
- `argocd_application.grafana`
- `argocd_application.networking`
- `argocd_application.observability`
- etc.

Argo CD manages:

- Deployments
- Services
- CRDs
- HTTPRoutes
- Helm/Kustomize rendering
- sync/prune/self-heal

This gives a clean compromise:

```text
Terraform = source of truth for core app inventory and dependency graph
Argo CD   = source of truth for Kubernetes reconciliation
```

Non-core apps can later be added directly through Argo CD, not Terraform.

### 40-post-config

Purpose: configure cross-app state that cannot be expressed cleanly as Helm/Kustomize.

Examples:

- configure Forgejo OIDC auth source
- create Forgejo OAuth application for Woodpecker
- configure identity-provider clients if using Terraform provider
- write Kubernetes Secrets that downstream apps consume
- smoke tests

Use this stage sparingly.

Prefer the following order:

1. Helm values / env / declarative app config
2. Identity provider blueprints / CRDs / native GitOps config
3. Terraform provider
4. Idempotent Kubernetes Job
5. Manual setup, only during PoC

## Argo CD organization

Use Argo CD AppProjects.

Suggested projects:

### platform

For core platform apps.

Can deploy cluster/platform resources. Restricted to the infrastructure repo.

Examples:

- Cilium
- Gateway
- cert-manager
- external-dns
- identity provider
- Forgejo
- Woodpecker
- Grafana
- observability

### projects

For friend/side-project apps.

Restrictions:

- only approved source repos
- only `projects-*` / `app-*` namespaces
- no cluster-scoped resources
- no CRDs
- no ClusterRole/ClusterRoleBinding
- limited resource kinds

### sandbox

Optional.

For experiments with even tighter namespace restrictions.

Use OIDC groups to map users into Argo roles.

## Networking and ingress

Use modern Kubernetes networking:

```text
CNI:
  Cilium

North-south routing:
  Gateway API

Gateway implementation:
  Cilium Gateway API

Cloud load balancer:
  Hetzner Cloud Controller Manager

Service-mesh observability:
  Cilium Hubble + Hubble UI
```

Cilium handles CNI, NetworkPolicy, Gateway API, kube-proxy replacement, and observability through Hubble. Using Cilium's own Gateway implementation keeps the networking stack to a single component. Hubble UI is the modern replacement for Weave Scope's topology view and is included in core v0.

Use Gateway API instead of legacy Ingress as the primary routing model.

Platform-owned:

- GatewayClass
- public Gateway
- TLS/certificate policy
- route attachment policy
- load balancer service

App-owned:

- HTTPRoute per app

Example:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: forgejo
  namespace: forgejo
spec:
  parentRefs:
    - name: public
      namespace: gateway-system
  hostnames:
    - git.example.com
  rules:
    - backendRefs:
        - name: forgejo
          port: 3000
```

Use Gateway `allowedRoutes` to restrict which namespaces can attach routes.

## DNS

Domains are hosted at Cloudflare.

Use split ownership:

```text
Terraform:
  base zone lookup
  bootstrap records if needed
  Cloudflare tokens
  maybe wildcard fallback

external-dns:
  app hostnames
  HTTPRoute/Gateway-derived records
```

Default approach:

- Terraform creates or references Cloudflare API token(s).
- Argo deploys external-dns.
- Apps define hostnames in HTTPRoutes.
- external-dns creates/updates Cloudflare DNS records.

Prefer DNS-only records initially. Cloudflare proxying can be enabled later per app once TLS/routing behavior is stable.

Optional simple mode:

```text
Terraform creates:
  *.example.com → Hetzner LB
```

This is easier but less explicit.

## TLS

Use cert-manager.

Use Cloudflare DNS-01 challenges instead of HTTP-01.

Reasons:

- works before public ingress is fully stable
- supports wildcard certificates
- avoids some Cloudflare proxy/TLS edge cases
- lets the platform own certificates centrally

Use scoped Cloudflare API tokens, not global API keys.

## Identity and authentication

The platform uses **authentik** as central OIDC provider.

Reasons:

- good product UX
- Terraform provider for declarative client/group/role config
- blueprints for declarative bootstrap config
- good fit for small self-hosted SSO

Authentik is not CRD/operator-driven, which means some config lives in the Terraform provider rather than in Argo CD. This is a deliberate tradeoff for product maturity.

Alternatives considered and deferred:

- **Kanidm + Kaniop** — closer to "identity as Kubernetes CRDs" and a better philosophical fit for GitOps, but younger ecosystem. Revisit if authentik becomes a pain point.
- **Keycloak** — mature but heavier and more operationally awkward for this scale.

Keep the identity layer behaviourally replaceable: apps consume OIDC via Kubernetes Secrets, so swapping IdPs later is a matter of issuing new client credentials and pointing Argo at a different chart, not re-architecting.

## Kubernetes API authentication

Enable Kubernetes API OIDC for normal human access.

Keep cert-based admin auth for bootstrap and break-glass.

Auth modes:

```text
cert-based kubeconfig:
  bootstrap / emergency / automation

OIDC:
  normal human kubectl access

ServiceAccounts:
  controllers and in-cluster automation
```

The kube-apiserver OIDC config belongs in the cluster layer, not in an app chart.

Example conceptual Talos API server args:

```yaml
cluster:
  apiServer:
    extraArgs:
      oidc-issuer-url: "https://auth.example.com/application/o/kubernetes/"
      oidc-client-id: "kubernetes"
      oidc-username-claim: "preferred_username"
      oidc-groups-claim: "groups"
      oidc-username-prefix: "oidc:"
      oidc-groups-prefix: "oidc:"
```

Bind OIDC groups through Kubernetes RBAC.

Example:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: oidc-admins
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: Group
    name: oidc:kubernetes-admins
    apiGroup: rbac.authorization.k8s.io
```

## Core applications

Keep default core small.

### Milestone 1 core

- Argo CD
- Cilium (CNI + Gateway API + Hubble UI)
- cert-manager
- external-dns
- Velero

### Milestone 2 core

- SOPS + age
- authentik
- Forgejo (incl. user-artifact registry)
- zot (platform/internal registry)
- Woodpecker
- Prometheus
- Loki
- Grafana

### Defer

- Plane
- OpenProject
- Nextcloud
- Harbor
- Tempo
- OpenTelemetry Collector
- SigNoz / Uptrace
- CloudNativePG as reusable platform database
- autoscaled worker nodes
- Rancher / Omni / Cluster API fleet management

## Git hosting

Use Forgejo.

Responsibilities:

- Git repositories
- issues/projects initially
- package/container registry initially
- OAuth provider for Woodpecker

Forgejo may need app-specific bootstrap because some auth configuration is not fully file/env driven.

Preferred order for Forgejo auth setup:

1. Helm chart support if sufficient
2. Terraform provider
3. idempotent Kubernetes Job using Forgejo CLI/API

## CI

Use Woodpecker.

Woodpecker should integrate with Forgejo, not directly with the central IdP.

Flow:

```text
central IdP
  → Forgejo login
  → Woodpecker login via Forgejo OAuth
```

Bootstrap requirements:

- Forgejo OAuth app for Woodpecker
- Woodpecker client ID/secret stored in Kubernetes Secret
- Woodpecker env vars reference that Secret

## Container registry

The platform runs **two registries** with different roles.

### Forgejo registry — user/dev artifacts

Forgejo's built-in OCI registry is the target for images built by user/project CI.

Use cases:

- images built by Woodpecker pipelines from user repos
- per-user/per-project artifact namespaces
- packages tied to Forgejo identity and permissions

Pros: integrated with Git, single source of credentials.

Cons: Forgejo registry has historically had rough edges under load. Acceptable for project artifacts where re-pushing on failure is fine.

### zot — platform/internal images

zot is the registry for critical platform images:

- mirrored upstream base images
- cluster operator images we want to pin/control
- internal utilities the platform depends on
- anything where availability matters more than convenience

Pros: lightweight, registry-only mental model, clean separation from Forgejo's blast radius.

Cons: less product UI. Auth model needs explicit design (likely htpasswd at first, OIDC via authentik once that's up).

### Registry contract

Apps and pipelines reference registries through a contract object, not hardcoded URLs:

```hcl
container_registries = {
  user = {
    url               = "git.example.com"
    push_secret_name  = "forgejo-registry-push"
    pull_secret_name  = "forgejo-registry-pull"
    namespace_pattern = "{user}/{repo}/{image}"
  }

  platform = {
    url               = "registry.example.com"
    push_secret_name  = "zot-push"
    pull_secret_name  = "zot-pull"
    namespace_pattern = "platform/{component}"
  }
}
```

### Harbor

Not used. Available as a future profile if vulnerability scanning, robot accounts, or project RBAC become needs the simpler stack can't meet.

## Observability

Default observability stack:

- Grafana
- Prometheus
- Loki
- Hubble UI

Cilium Hubble UI is the closest modern replacement for the old Weave Scope topology experience. It provides service dependency and connectivity visualization.

Optional later:

- Tempo
- OpenTelemetry Collector
- SigNoz or Uptrace
- Headlamp for Kubernetes UI

Keep the first version lightweight.

## Backup and disaster recovery

The PoC is single-node. A node loss without backups is a total loss. Backup is in-scope for milestone 1.

### Components

**Velero** for Kubernetes resource and PV backups:

- scheduled cluster-state backups (manifests, ConfigMaps, Secrets)
- scheduled PV/PVC backups via CSI snapshots
- restore-to-empty-cluster capability

**Talos etcd snapshots** for control-plane state:

- Talos has built-in etcd snapshot scheduling
- snapshots cover the cluster's source-of-truth control-plane state

### Storage target

**Hetzner Object Storage** (S3-compatible, same provider as cluster).

Tradeoff: same-vendor blast radius. A Hetzner-wide outage hits both cluster and backups simultaneously. Acceptable for the PoC; revisit when moving to HA or production-critical workloads.

Bucket layout:

```text
backups-<env>/
  velero/
  etcd/
```

### Retention

Default starting point:

- Velero daily backups, 14-day retention
- etcd snapshots every 6 hours, 7-day retention

### Restore drills

Schedule a quarterly restore drill against a throwaway cluster. Untested backups are not backups.

## Secrets strategy

### Current state

The existing stack uses git-crypt.

git-crypt transparently encrypts selected files in Git and decrypts them on checkout for users with the key.

This is good for a small personal repo, but it is less ideal for GitOps/Kubernetes because:

- Argo CD cannot naturally decrypt git-crypt files unless the repo is unlocked inside the repo-server.
- Decryption is checkout/worktree-oriented.
- It is too broad/transparent; reviewers may not see which fields are encrypted.
- It is awkward for per-environment secret recipients.
- Key rotation and CI/agent access are clumsy.
- It does not naturally produce Kubernetes Secrets on the destination cluster.

### Recommendation

Move Kubernetes/GitOps secrets to SOPS with age.

SOPS supports structured secret files and works better with GitOps workflows.

Use SOPS for:

- Kubernetes Secret manifests
- Helm values containing secret values
- per-environment encrypted files
- Cloudflare/Hetzner tokens if they must live in Git
- OAuth client secrets if generated outside Terraform

Use age keys initially.

Example `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: terragrunt/envs/hcloud-poc/.*\.sops\.ya?ml$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

  - path_regex: applications/.*\.sops\.ya?ml$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Argo CD secret integration

There are two broad GitOps secret approaches:

1. decrypt during manifest generation in Argo CD
2. populate secrets on the destination cluster

For this scaffold, prefer:

```text
SOPS + age for Git encryption
plus a destination-cluster secret controller where possible later
```

Good options:

### Option A: SOPS + KSOPS / Argo plugin

Argo CD decrypts SOPS files during manifest generation.

Pros:

- straightforward GitOps flow
- encrypted Kubernetes Secret manifests live next to apps
- no external secret backend required

Cons:

- Argo repo-server needs decryption capability/key
- plugin/customization complexity
- less ideal security boundary than destination-cluster population

### Option B: External Secrets Operator

External Secrets Operator synchronizes secrets from external APIs into Kubernetes Secrets.

Pros:

- aligns well with destination-cluster secret population
- better long-term model
- supports many external stores
- keeps raw secret values out of rendered GitOps manifests

Cons:

- requires an external secret backend
- more moving pieces
- for a friend-group scaffold, choosing the backend is non-trivial

Possible backends later:

- 1Password
- Bitwarden / Vaultwarden if supported through provider
- Vault
- cloud secret manager
- Kubernetes secret store for simple bootstrap cases

### Option C: Terraform-generated secrets

Terraform generates secrets with `random_password` and writes Kubernetes Secrets.

Pros:

- simple for OAuth client secrets shared between IdP and app
- avoids IdP-generated-secret chicken/egg problem
- Terraform can pass values to multiple providers/resources

Cons:

- secrets land in Terraform state
- state backend must be secured
- not ideal for all app secrets

Use this for cross-system bootstrap secrets where Terraform already owns both sides.

### Suggested initial approach

Two disjoint secret paths. They do not feed into each other.

**Path A — SOPS + age: secrets that live in Git**

Source-of-truth: human-authored, version-controlled.

Used for:

- inputs to Terraform from the outside world (Cloudflare API token, Hetzner token)
- human-authored Kubernetes Secrets (third-party API keys, deploy keys, app config secrets)

Flow:

1. operator runs `sops --encrypt` locally on a `*.sops.yaml` file under `secrets/`
2. commits the encrypted file
3. consumers decrypt:
   - Terraform via the `carlpett/sops` provider on plan/apply
   - Argo CD via the KSOPS plugin in `argocd-repo-server`

Plaintext never enters Git.

**Path B — Terraform-generated: cross-system bootstrap secrets**

Source-of-truth: Terraform state.

Used for:

- OAuth client secrets shared between IdP and app
- anything Terraform must wire into multiple systems atomically

Flow:

1. `random_password` resource generates the value
2. Terraform writes it as a `kubernetes_secret` (consumed by the app)
3. Terraform configures the matching value in the IdP via the authentik provider
4. Lives in: TF state + K8s Secret + IdP. **Never in Git, never in SOPS.**

Cost: TF state contains plaintext for these secrets. The state backend must be encrypted at rest.

**External Secrets Operator** — deferred. Becomes Path C if/when a real external secret backend is introduced.

### Age key lifecycle

The age key is generated **once per Git history**, not once per cluster lifetime. As long as encrypted files exist in Git, the key that decrypts them must exist too. Tearing down and rebuilding the cluster reuses the same key.

**Multiple recipients from day 1.** SOPS supports encrypting to multiple age public keys. Use this:

```yaml
creation_rules:
  - path_regex: secrets/.*\.sops\.ya?ml$
    age: >-
      age1operator...,
      age1backup...
```

Either key alone can decrypt. Standard split:

- `operator` key — daily use, kept in a password manager
- `backup` key — offline, kept on a hardware token or in cold storage

Loss of one is not a lockout. Adding a co-maintainer later is "add their public key, re-encrypt the affected files", not a key migration.

**Bootstrap path for the cluster.** The age private key cannot itself live in SOPS (chicken/egg). To get it into `argocd-repo-server`:

1. operator generates the age key once with `age-keygen`
2. stores both halves in a password manager (and a backup recipient in cold storage)
3. provides the private key to Terraform as a variable on first apply (`TF_VAR_argocd_age_key`)
4. Terraform writes it to the cluster as a Kubernetes Secret that `argocd-repo-server` mounts via the KSOPS plugin config

Tearing down the cluster doesn't lose the key — it's still in the password manager. The next bootstrap reads it from `TF_VAR_argocd_age_key` again.

**Rotation** is a real operation, not transparent: `sops updatekeys` rewrites every file with the new recipient set. Plan for it but don't expect to do it routinely.

### Migrating off git-crypt

Avoid relying on git-crypt for new Kubernetes secrets. Keep git-crypt temporarily for existing secrets during migration, but do not build new flows around it.

### Secret ownership rule

Avoid this:

```text
IdP generates secret
  → Terraform/Helm must discover it
  → app consumes it
```

Prefer this:

```text
Secret source generates secret
  ├─ IdP consumes it
  └─ app consumes it
```

For OAuth clients:

- Generate client secret in Terraform or SOPS.
- Configure IdP client with that value.
- Configure app with same value via Kubernetes Secret.

This keeps the dependency graph acyclic.

## Terraform / Argo CD boundary

Terraform should own:

- cloud resources
- machines
- cluster bootstrap
- Argo CD installation
- Argo CD Projects
- core Argo CD Applications
- generated bootstrap secrets
- cross-app provider config where needed

Argo CD should own:

- Kubernetes application resources
- Helm/Kustomize rendering
- CRDs and custom resources after bootstrap
- HTTPRoutes
- app Deployments/Services
- project apps

Avoid Terraform managing arbitrary Kubernetes manifests after Argo CD is running.

Reason: Terraform’s Kubernetes provider often needs resource schemas during planning. CRDs must exist before custom resources can be planned, which causes awkward multi-stage applies. Terraform is not a great owner for arbitrary unknown Kubernetes resources.

## Wait boundaries

Expected wait points:

1. after cluster creation — wait for kube-apiserver
2. after Argo CD installation — wait for `argocd-server` Available
3. after core apps sync — wait for `core` Argo Application Synced + Healthy
4. before post-config providers talk to apps — wait for app readiness

Implement waits as `terraform_data` resources with `local-exec` provisioners inside the Terragrunt modules that own them.

Example inside `20-argocd`:

```hcl
resource "terraform_data" "argocd_ready" {
  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    command = "kubectl -n argocd wait deploy/argocd-server --for=condition=Available --timeout=10m"
  }
}
```

Example inside `30-core-apps`:

```hcl
resource "terraform_data" "core_synced" {
  depends_on = [argocd_application.core_root]

  provisioner "local-exec" {
    command = "argocd app wait core --sync --health --timeout 900"
  }
}
```

Why this over a wrapper script:

- waits live next to the resources they wait for
- Terragrunt's dependency graph carries the ordering
- re-running `terragrunt apply` is idempotent because `terraform_data` tracks completion
- no separate orchestration layer to debug

Tradeoff: the Terragrunt runner needs `kubectl` and `argocd` CLI on `$PATH`.

## Local testing

Provide at least one local environment.

Suggested targets:

### local-fast

Use Talos-in-Docker or kind.

Tests:

- Argo CD bootstrap
- AppProjects
- Argo Applications
- Helm/Kustomize rendering
- Gateway/HTTPRoute manifests
- secret handling
- Forgejo/Woodpecker/Grafana deployment shape
- bootstrap Jobs

Does not faithfully test:

- Hetzner load balancers
- Hetzner CSI
- Hetzner cloud-controller-manager
- real DNS/TLS
- real VM sizing

### hcloud-poc

Tests real cloud integration:

- Hetzner networking
- Hetzner LoadBalancer
- Hetzner CSI
- Cloudflare DNS
- cert-manager DNS-01
- actual VM replacement
- actual memory sizing

Environment layout:

```text
terragrunt/envs/
  local/
    00-machines/
    10-cluster/
    20-argocd/
    30-core-apps/

  hcloud-poc/
    00-machines/
    10-cluster/
    20-argocd/
    30-core-apps/
```

## Multi-cluster / future management

If using RKE2, Rancher is the natural future management UI.

If using Talos, Sidero Omni is the native Talos fleet-management product, but it is source-available / business-licensed for production self-hosting.

A Talos cluster can still be imported into Rancher later as a generic Kubernetes cluster, but Rancher will not manage Talos OS lifecycle.

For open-source future management:

- keep Terragrunt + Argo CD for now
- use Argo CD multi-cluster first
- consider Cluster API + Talos providers later if cluster lifecycle becomes a real fleet problem

Do not introduce Rancher/Omni/Cluster API in the first scaffold unless there is a concrete need.

## Suggested repository shape

```text
.
├── README.md
├── ARCHITECTURE.md
├── scripts/
│   ├── deploy
│   ├── wait-for-argocd
│   ├── wait-for-core
│   └── smoke-test
├── terragrunt/
│   ├── root.hcl
│   ├── envs/
│   │   ├── hcloud-poc/
│   │   │   ├── env.hcl
│   │   │   ├── 00-machines/
│   │   │   ├── 10-cluster/
│   │   │   ├── 20-argocd/
│   │   │   ├── 30-core-apps/
│   │   │   └── 40-post-config/
│   │   └── local/
│   │       ├── env.hcl
│   │       ├── 00-machines/
│   │       ├── 10-cluster/
│   │       ├── 20-argocd/
│   │       └── 30-core-apps/
│   └── modules/
│       ├── machines/
│       │   ├── hcloud/
│       │   └── static/
│       ├── cluster/
│       │   └── talos/
│       ├── argocd/
│       │   ├── install/
│       │   ├── project/
│       │   └── application/
│       └── post-config/
│           ├── forgejo-auth/
│           └── identity-clients/
├── applications/
│   ├── networking/
│   │   ├── cilium/
│   │   ├── gateway/
│   │   ├── cert-manager/
│   │   └── external-dns/
│   ├── identity/
│   ├── forgejo/
│   ├── woodpecker/
│   ├── grafana/
│   ├── observability/
│   │   ├── prometheus/
│   │   ├── loki/
│   │   └── hubble-ui/
│   └── registry/
│       ├── forgejo/
│       └── zot/
└── secrets/
    ├── hcloud-poc/
    │   └── *.sops.yaml
    └── local/
        └── *.sops.yaml
```

### What lives where

- `terragrunt/` — infrastructure inventory and bootstrap. One `argocd_application.<name>` resource per core component.
- `applications/` — **core** app definitions only: chart references, Helm values overrides, Kustomize bases. Each TF-created `argocd_application.X` points at `applications/X/` in this repo.
- `secrets/` — SOPS-encrypted secrets keyed by environment.

**Non-core / friend-project apps do not live in this repo.** They live in their own Forgejo repos and are granted Argo CD access via the `projects` AppProject's `sourceRepos` allowlist. This repo is the platform; project apps are tenants.

## First implementation milestone

Implement the smallest coherent version that gets a real HTTPS request to a real app:

```text
1. 00-machines/hcloud
   1x 16 GB Hetzner VM
   Hetzner network, firewall, base DNS

2. 10-cluster/talos
   single-node Talos cluster
   kubeconfig output
   cert-based break-glass auth
   Talos etcd snapshot schedule

3. 20-argocd
   install Argo CD via Helm
   create AppProjects (platform, projects, sandbox)

4. 30-networking
   Cilium (CNI + Gateway API + Hubble UI)
   cert-manager
   external-dns
   Cloudflare DNS-01

5. 30-smoke-app
   one trivial app behind HTTPRoute + TLS
   real DNS record, real Let's Encrypt cert
   end-to-end proof of routing/TLS/DNS

6. backup
   Velero + Hetzner Object Storage
   Talos etcd snapshots → Hetzner Object Storage
   one manual restore drill
```

Stop here. Verify the loop works end-to-end before adding apps.

## Second implementation milestone

Once milestone 1 is solid:

```text
7.  SOPS + age
    encrypted secret files
    stop adding new git-crypt secrets

8.  identity
    authentik
    wire kube-apiserver OIDC
    bind OIDC groups to RBAC

9.  forgejo
    git hosting
    Forgejo registry for user artifacts
    OAuth source from authentik

10. zot
    platform image registry
    auth via authentik or htpasswd

11. woodpecker
    Forgejo OAuth bootstrap
    runners

12. observability
    Prometheus
    Loki
    Grafana
    Hubble UI already present from milestone 1

13. project self-service
    onboard the first friend project via the projects AppProject
```

## Later milestones

### HA milestone

Move from:

```text
1x 16 GB
```

to:

```text
3x 8 GB or 3x 16 GB
```

Ensure:

- etcd/control-plane joins cleanly
- gateway targets multiple nodes
- app scheduling works
- PodDisruptionBudgets and anti-affinity added where useful

### Project self-service hardening

Tighten the `projects` AppProject as more friend projects come on:

- restrict allowed source repos
- enforce namespace patterns
- limit resource kinds
- audit RBAC

### Secret backend milestone

Introduce External Secrets Operator when there is a chosen external secret backend.

### Observability-plus milestone

Add Tempo/OpenTelemetry/SigNoz/Uptrace only if actually needed.

### Heavy registry profile

Replace or augment zot with Harbor if vulnerability scanning, robot accounts, or richer RBAC become needs.

### Cross-region or external backup

Add a second backup target outside Hetzner (Backblaze B2, Cloudflare R2) when steady-state workloads justify the same-vendor blast-radius mitigation.

## Key design principles

1. Keep the first scaffold small.
2. Use Terraform/Terragrunt for infrastructure and app inventory, not arbitrary Kubernetes resources.
3. Use Argo CD for Kubernetes reconciliation.
4. Use Gateway API instead of legacy Ingress as the primary routing model.
5. Use external-dns for app DNS records.
6. Keep cert-based cluster admin access even after enabling OIDC.
7. Generate shared OAuth secrets outside both the IdP and the app.
8. Prefer SOPS + age over git-crypt for new Kubernetes/GitOps secrets.
9. Make the registry backend replaceable.
10. Start single-node if cost matters; move to HA later.
