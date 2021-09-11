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
      name: Auth0
      issuer: ${auth0_domain}/
      clientID: ${client_id}
      clientSecret: ${client_secret}
      requestedIDTokenClaims:
        groups:
          essential: true
      requestedScopes:
      - openid
      - profile
      - email
      - 'https://argocd.${domain}/claims/groups'
  rbacConfig:
    policy.csv: |
      g, argo-admins, role:admin
    scopes: '[https://argocd.${domain}/claims/groups, email]'
configs:
  repositories:
    infrastructure:
      url: git@github.com:tiborpilz/infrastructure
  credentialTemplates:
    ssh-creds:
      url: git@github.com:tiborpilz
      sshPrivateKey: |
        ${indent(8, github_private_key)}
