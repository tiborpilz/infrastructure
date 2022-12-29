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
    redirect_url = "https://oauth.bababourbaki.dev/oauth2/callback"
    oidc_issuer_url = "${issuer_url}"
    whitelist_domains=".oauth.bababourbaki.dev"
    reverse_proxy = true
    email_domains = [ "*" ]
    scope = "email openid profile"
    cookie_domains = ".${host}"
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
    kubernetes.io/ingress.class: nginx
    kubernetes.io/tls-acme: "true"
  tls:
    - secretName: oauth-proxy-tls
      hosts:
        - oauth.${host}
