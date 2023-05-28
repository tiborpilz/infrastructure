# Oauth client configuration specifics
config:
  clientID: ${client_id}
  clientSecret: ${client_secret}
  # Create a new secret with the following command
  # openssl rand -base64 32 | head -c 32 | base64
  cookieSecret: "elZtbi9vWTdsNkltSDJDak5zbFllcEVQcDZmOXJ0RFU="
  configFile: |-
    provider = "oidc"
    provider_display_name = "Keycloak"
    redirect_url = "https://oauth.${domain}/oauth2/callback"
    oidc_issuer_url = "${issuer_url}"
    whitelist_domains=".${domain}"
    reverse_proxy = true
    email_domains = [ "*" ]
    scope = "email openid profile"
    cookie_domains = ".${domain}"
    pass_authorization_header = true
    pass_access_token = true
    pass_user_headers = true
    set_authorization_header = true
    set_xauthrequest = true
    cookie_refresh = "1m"
    cookie_expire = "30m"
    upstreams = [ "file:///dev/null" ]

ingress:
  enabled: true
  hosts:
    - oauth.${domain}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-clusterissuer
    kubernetes.io/ingress.class: nginx
    kubernetes.io/tls-acme: "true"
    # nginx.ingress.kubernetes.io/rewrite-target: /oauth2
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/server-snippet: |
      large_client_header_buffers 4 32k;
  tls:
    - secretName: oauth-proxy-tls
      hosts:
        - oauth.${domain}
