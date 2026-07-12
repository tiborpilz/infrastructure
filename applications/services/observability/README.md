# Observability

A self-hosted, SigNoz-equivalent stack covering all three signals — metrics,
logs and traces — unified in Grafana and wired into Authentik SSO, ArgoCD and
the Gateway API.

## Data flow

Apps emit OTLP to the OpenTelemetry Collector, which fans out: traces to
Jaeger, metrics to Prometheus (remote-write), logs to Loki. Grafana reads all
three and links them — log→trace via a derived field, trace→logs/metrics via
datasource links.

Alloy runs as a DaemonSet and tails pod logs into Loki independently. It reads
through the Kubernetes API rather than a hostPath mount so it stays compatible
with Talos and `restricted` pod-security; that needs the extra `pods/log`
grant in `alloy-rbac.yaml`.

## Access (SSO)

Grafana is exposed with its own OIDC against Authentik — the `grafana-admins`
group maps to Admin. Jaeger's UI sits behind oauth2-proxy, the same pattern as
Hubble and Headlamp. OIDC client secrets live in `secrets.enc.yaml`, reflected
into the `authentik` namespace where the blueprints under `blueprints/`
register matching providers.

## SigNoz (parallel stack)

SigNoz runs alongside the Grafana stack for a side-by-side feature comparison —
it is not a replacement (yet). It brings its own ClickHouse-backed data plane
(`argo-app-signoz.yaml`: ClickHouse + Zookeeper + query/UI + its own OTEL
collector). No app changes are needed to feed it: the shared `otel-collector`
fans the **same** OTLP stream (traces, metrics, logs) into
`signoz-otel-collector:4317` in addition to Jaeger/Prometheus/Loki, so both
stacks see identical telemetry.

The UI (`signoz.tibor.sh`) sits behind oauth2-proxy — SigNoz Community has no
built-in OIDC login, so it uses the same gating pattern as Jaeger/Hubble, with
an Authentik provider from `blueprints/signoz.yaml`.

**ClickHouse is the heavy part** — it and Zookeeper are new stateful workloads
on `ceph-block`. Sizes/limits in `argo-app-signoz.yaml` are conservative
starting points; watch memory and bump against the live cluster.

### Finishing SSO (manual, one-time)

The OIDC secret couldn't be sops-encrypted in the authoring sandbox (no sops
binary / private key there). Until it exists, the SigNoz pods run but the
oauth2-proxy in front of the UI stays down. To finish:

1. Fill in `secrets-signoz.enc.yaml.example` (`client-secret`: `openssl rand
   -hex 32`, `cookie-secret`: `openssl rand -base64 32`).
2. `sops --encrypt --input-type yaml --output-type yaml
   secrets-signoz.enc.yaml.example > secrets-signoz.enc.yaml`, then delete the
   `.example`.
3. Uncomment `- secrets-signoz.enc.yaml` in `kustomization.yaml`.

The `SIGNOZ_OIDC_CLIENT_SECRET` wiring in `identity/authentik/argo-app.yaml`
reads the same `client-secret` key, so both sides stay in sync automatically.

## Operational notes

- **Chart versions** are pinned to known-good releases. Verify and bump against
  the live cluster — the authoring sandbox can't reach the Helm repos to
  resolve latest.
- **Secrets** are sops-encrypted to the age recipients only, not the PGP key in
  `.sops.yaml` (it wasn't reachable at authoring time). The cluster decrypts
  with its age key, so deploys work; run `sops updatekeys secrets.enc.yaml` to
  add the PGP recipient back.
