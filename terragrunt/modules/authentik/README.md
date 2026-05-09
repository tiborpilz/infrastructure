# `authentik` module — central OIDC provider

Deploys authentik (https://goauthentik.io) as the platform's identity provider, plus its data plane (CNPG-managed Postgres + an inlined Valkey).

## What this layer does

1. **Namespace** — `authentik`.
2. **Bootstrap secrets** — TF-generated `random_password` for `secret_key`, `bootstrap_admin_token`, `bootstrap_admin_password`, `valkey_password`. Path B in PLAN.md's secret strategy: lives in TF state, never in Git.
3. **Secrets in the namespace** — `authentik-bootstrap` (mounted via `global.envFrom` so server + worker both pick up `AUTHENTIK_*` env vars) and `authentik-valkey` (single-key Secret consumed by the Valkey StatefulSet's `--requirepass`).
4. **Argo CD Application — authentik** — chart `authentik` from `https://charts.goauthentik.io`. Postgres and Valkey are injected via `additionalObjects`:
   - `Cluster.postgresql.cnpg.io` — managed by the CNPG operator from `35-platform-data`. PVC backed by `hcloud-volumes`.
   - `Service` + `StatefulSet` `authentik-valkey` — vanilla `valkey/valkey:8` image, single replica, `emptyDir`. No operator (the valkey-operator ecosystem isn't mature yet; sessions/cache survive pod restarts via Postgres-stored sessions and re-issue on connection).
5. **HTTPRoute** — `auth.<domain>` attached to the public Gateway. external-dns creates the Cloudflare record; the Gateway's wildcard cert covers it.
6. **Readiness gate** — `terraform_data` with a `local-exec` that waits for the Argo CD Application to be Healthy, the server pods Ready, and `/-/health/ready/` to return 200. Downstream layers depend on this.

## What this layer does NOT do

- No per-app OIDC clients. Each consumer module (Forgejo, Woodpecker, Grafana, …) declares its own `authentik_provider_oauth2` + `authentik_application` + `random_password` for the OIDC client_secret. Per-app identity config lives WITH the app, not centrally.
- No general authentik state (admin password pinning, groups). That's `45-authentik-config`.
- No Postgres backups. CNPG WAL archives stay on the PV until Velero/S3 wiring lands.
- No Valkey persistence. authentik's session store can lose state on Valkey restart (effectively logs everyone out); acceptable for PoC.

## Inputs

See `variables.tf`. Required:

- cluster connection (`kubernetes_host`, `cluster_ca_certificate`, `client_certificate`, `client_key`)
- `kubeconfig_path` — for the readiness `local-exec`
- `domain`, `subdomain` — together produce the public URL (default `auth.<domain>`)
- `gateway_namespace`, `gateway_name` — from `30-networking`
- `platform_data_ready` — sentinel from `35-platform-data` (forces dependency)
- `admin_email` — for the bootstrap `akadmin` user
- the four rendered template strings: `authentik_values_yaml`, `database_yaml`, `valkey_service_yaml`, `valkey_statefulset_yaml`

## Outputs

- `authentik_namespace`, `authentik_url`
- `bootstrap_admin_token` (sensitive) — consumed by `45-authentik-config`
- `bootstrap_admin_password` (sensitive) — first-login fallback before `45-authentik-config` rotates it
- `ready` — boolean sentinel for downstream

## Why values get reassembled in Terraform

The chart's `additionalObjects` does `range . { tpl (toYaml .) $ }`. Each item must be a structured object (dict), not a YAML block-scalar string. So we:

1. Render each YAML template (`values.yaml.tpl`, `database.yaml.tpl`, `valkey-service.yaml.tpl`, `valkey-statefulset.yaml.tpl`) to a string in the env layer via `templatefile()`.
2. In Terraform, `yamldecode` each string into a structured value.
3. `merge(base_values, { additionalObjects = [db, vk_svc, vk_sts] })`.
4. `yamlencode` and pass as the Application's helm.values.

Argo CD then ships the rendered values to the chart, which `tpl`-templates and applies each additionalObjects entry as a real k8s object.

## Notes

- **Why no helm_release?** Same reason as `30-networking`: writing the Application via `kubectl_manifest` keeps Argo CD as the runtime owner and Terraform as the inventory owner. PLAN.md "Terraform / Argo CD boundary".
- **CRD ordering:** the Cluster CR ships in the same Application as authentik. Argo CD applies it after the CNPG operator has been installed (gated by `platform_data_ready`); first-sync timing depends on Argo CD's reconcile interval. The readiness `local-exec` covers this.
- **Token lifecycle:** the bootstrap admin token is created by authentik's bootstrap Job from the env Secret. Its value is whatever we wrote to `AUTHENTIK_BOOTSTRAP_TOKEN`. Pinned to TF state — re-bootstraps reuse the same token unless we taint the `random_password`.
