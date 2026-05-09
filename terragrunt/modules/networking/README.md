# `networking` module — TLS, DNS, public Gateway

Turns the cluster from "Argo CD running, no public exposure" to "any HTTPRoute can have HTTPS at `*.<domain>`".

## What this layer does

1. **Namespaces** — `cert-manager`, `external-dns`, `gateway-system`.
2. **Cloudflare API token Secret** — placed in both `cert-manager` and `external-dns`. Single-source-of-truth via `var.cloudflare_api_token`.
3. **Argo CD Application — cert-manager** — Helm chart with a `letsencrypt-prod` ClusterIssuer wired to Cloudflare DNS-01 (DNS-01 supports wildcards; HTTP-01 doesn't).
4. **Argo CD Application — external-dns** — Helm chart with the Cloudflare provider, watching `gateway-httproute` (Gateway API mode, not legacy Ingress).
5. **Public Gateway** — `gatewayClassName: cilium`, single HTTPS listener for `*.<domain>`. The `cert-manager.io/cluster-issuer` annotation triggers cert-manager to issue and populate the wildcard TLS Secret.

## What this layer does NOT do

- No HTTPRoute resources. Apps create their own HTTPRoute attached via `parentRefs` to this Gateway.
- No HTTP-to-HTTPS redirect listener on port 80. Add one if needed; M1 keeps it minimal.
- No tightening of the AppProject's `sourceRepos` allowlist — that comes when project apps onboard.

## Bootstrap order

```
cloudflare-api-token Secret  (TF, in two namespaces)
   ↓
Argo CD Application: cert-manager  (TF creates CR, Argo applies chart)
   ↓ (cert-manager pods come up, ClusterIssuer reconciles)
Public Gateway  (TF creates CR; cert-manager sees annotation, issues cert)
   ↓
external-dns watches HTTPRoutes attached to this Gateway and creates Cloudflare records
```

## Inputs

See `variables.tf`. Required: cluster connection (`kubernetes_host`, `cluster_ca_certificate`, `client_certificate`, `client_key`), `domain`, `cloudflare_api_token`, plus the rendered Helm values strings (`cert_manager_values`, `external_dns_values`).

## Outputs

`gateway_namespace`, `gateway_name`, `wildcard_tls_secret` — for the smoke app to attach to the Gateway.

## Notes

- **Wildcard cert via Gateway annotation** requires cert-manager v1.16+. We're on v1.20.x; supported.
- **Why kubectl_manifest, not the argocd provider?** Avoids pulling in another provider that would need API connection details and admin creds. Application CRs are just Kubernetes resources; kubectl applies them; Argo CD reconciles.
- **DNS propagation**: the first cert issuance can take 1-5 minutes. cert-manager creates a TXT record at Cloudflare, ACME validates, then deletes the TXT. Watch with `kubectl -n cert-manager get certificaterequests,orders,challenges -A`.
