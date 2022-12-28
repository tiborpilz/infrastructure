# Oauth client configuration specifics
config:
  clientID: ${client_id}
  clientSecret: ${client_secret}
  # Create a new secret with the following command
  # openssl rand -base64 32 | head -c 32 | base64
  cookieSecret: ${cookie_secret}
  configFile: |-
    provider = "oidc"
    provider_display_name = "Keycloak"
    oidc_issuer_url = "${issuer_url}"
    email_domains = [ "*" ]
    scope = "openid profile email"
    cookie_domains = [".${host}"]
    whitelist_domains = ".${host}"
    pass_authorization_header = true
    pass_access_token = true
    pass_user_headers = true
    set_authorization_header = true
    set_xauthrequest = true
    cookie_refresh = "1m"
    cookie_expire = "30m"

ingress:
  enabled: true
  path: /
  hosts:
    - oauth.${host}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-clusterissuer
    nginx.ingress.kubernetes.io/proxy-buffer-size: "16k"
  tls:
    - secretName: oauth-proxy-tls
      hosts:
        - oauth.${host}
