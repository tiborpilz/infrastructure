# external-dns Helm values, templated by Terragrunt.
# See https://github.com/kubernetes-sigs/external-dns/tree/master/charts/external-dns for the full schema.

provider:
  name: cloudflare

# CF_API_TOKEN comes from the cloudflare-api-token Secret in this namespace.
env:
  - name: CF_API_TOKEN
    valueFrom:
      secretKeyRef:
        name: cloudflare-api-token
        key: token

# Watch HTTPRoute resources (Gateway API), not the legacy Ingress source.
sources:
  - gateway-httproute

domainFilters:
  - "${domain}"

# sync = also delete records when the corresponding HTTPRoute is removed.
policy: sync

# Single replica for the PoC.
replicaCount: 1

# Useful for debugging during M1.
logLevel: info
