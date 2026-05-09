# `smoke-app` module

End-to-end verification for milestone 1: a trivial nginx app behind an HTTPRoute attached to the public Gateway. If `curl https://<subdomain>.<domain>` returns 200, the entire stack works:

- DNS (external-dns → Cloudflare)
- TLS (cert-manager → wildcard Let's Encrypt cert)
- Routing (Cilium Gateway → HTTPRoute → Service → Pod)
- Cluster (Talos + Cilium CNI + Hetzner CCM)

This is a disposable verification asset, not a permanent platform component. Delete with `terragrunt destroy` when no longer useful.

## Resources

- `kubernetes_namespace.smoke` — namespace for the test app
- `kubernetes_deployment_v1.nginx` — single replica, default nginx
- `kubernetes_service_v1.nginx` — ClusterIP
- `kubectl_manifest.httproute` — HTTPRoute attached to the public Gateway in `gateway-system`

## Inputs

See `variables.tf`. Required: cluster connection material + `domain`.
