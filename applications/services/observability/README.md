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

## Operational notes

- **Chart versions** are pinned to known-good releases. Verify and bump against
  the live cluster — the authoring sandbox can't reach the Helm repos to
  resolve latest.
- **Secrets** are sops-encrypted to the age recipients only, not the PGP key in
  `.sops.yaml` (it wasn't reachable at authoring time). The cluster decrypts
  with its age key, so deploys work; run `sops updatekeys secrets.enc.yaml` to
  add the PGP recipient back.
