# cert-manager Helm values, templated by Terragrunt.
# See https://artifacthub.io/packages/helm/cert-manager/cert-manager for the full schema.

crds:
  enabled: true

# Enable the Gateway API integration so the gateway-shim controller watches
# Gateway resources with cert-manager.io/cluster-issuer annotations and
# auto-creates Certificate resources.
config:
  apiVersion: controller.config.cert-manager.io/v1alpha1
  kind: ControllerConfiguration
  enableGatewayAPI: true

# ClusterIssuer for Let's Encrypt with Cloudflare DNS-01 (supports wildcards).
# The cloudflare-api-token Secret is created by Terraform in the cert-manager
# namespace before this Application syncs.
#
# extraObjects entries must be strings (the chart `tpl`s each one); using a
# block scalar so the YAML body is delivered as text.
extraObjects:
  - |
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        email: ${email}
        server: https://acme-v02.api.letsencrypt.org/directory
        privateKeySecretRef:
          name: letsencrypt-prod-account-key
        solvers:
          - dns01:
              cloudflare:
                apiTokenSecretRef:
                  name: cloudflare-api-token
                  key: token
            selector:
              dnsZones:
                - "${domain}"
