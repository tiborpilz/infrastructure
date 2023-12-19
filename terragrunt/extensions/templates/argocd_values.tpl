server:
  ingress:
    enabled: true
    hosts:
      - argocd.${domain}
    tls:
      - hosts:
          - argocd.${domain}
        secretName: argocd-tls
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-clusterissuer
      kubernetes.io/ingress.class: nginx
      kubernetes.io/tls-acme: 'true'
      nginx.ingress.kubernetes.io/ssl-passthrough: 'true'
      nginx.ingress.kubernetes.io/backend-protocol: 'HTTPS'
    https: true
  configEnabled: true
  config:
    url: https://argocd.${domain}
    application.instanceLabelKey: argocd.argoproj.io/instance
    oidc.config: |
      name: Keycloak
      issuer: ${issuer_url}
      clientID: ${client_id}
      clientSecret: ${client_secret}
      requestedIDTokenClaims:
        groups:
          essential: true
      requestedScopes:
      - profile
      - email
      - groups
      - openid
  rbacConfig:
    policy.csv: |
      g, admin, role:admin
    scopes: '[https://argocd.${domain}/claims/groups, email, groups]'
configs:
  repositories:
    infrastructure:
      url: git@github.com:tiborpilz/infrastructure
