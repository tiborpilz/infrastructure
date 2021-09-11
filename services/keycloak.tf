resource "kubernetes_manifest" "keycloak-application" {
  depends_on = [helm_release.argocd]
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind = "Application"
    metadata = {
      finalizers = [
        "resources-finalizer.argocd.argoproj.io",
      ]
      name = "keycloak"
      namespace = "argocd"
    }
    spec = {
      destination = {
        name = "in-cluster"
        namespace = "keycloak"
        server = ""
      }
      project = "default"
      source = {
        path = "applications/keycloak"
        repoURL = "git@github.com:tiborpilz/infrastructure.git"
        targetRevision = "HEAD"
      }
      syncPolicy = {
        automated = {
          prune = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
        ]
      }
    }
  }
  wait_for = {
    fields = {
      "status.health.status" = "Healthy"
    }
  }
}

data "kubernetes_secret" "keycloak-client-secret-oauth-proxy" {
  depends_on = [kubernetes_manifest.keycloak-application]
  metadata {
    name = "keycloak-client-secret-oauth-proxy"
    namespace = "keycloak"
  }
}

output "oauth_proxy_id" {
  description = "ID of oauth2 proxy keycloak client"
  value = data.kubernetes_secret.keycloak-client-secret-oauth-proxy.data.CLIENT_ID
  sensitive = true
}

resource "kubernetes_manifest" "oauth2-proxy-application" {
  depends_on = [kubernetes_manifest.keycloak-application]
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind = "Application"
    metadata = {
      finalizers = [
        "resources-finalizer.argocd.argoproj.io",
      ]
      name = "oauth2-proxy"
      namespace = "argocd"
    }
    spec = {
      destination = {
        name = "in-cluster"
        namespace = "oauth2-proxy"
        server = ""
      }
      project = "default"
      source = {
        chart = "oauth2-proxy"
        helm = {
          values = yamlencode({
            extraArgs = {
              ssl-upstream-insecure-skip-verify = true
              keycloak-group = "/basic_user"
            }
            # extraEnv = [
            #   {
            #     name: "OAUTH2_PROXY_COOKIE_SECURE"
            #     value: false
            #   }
            # ]
            config = {
              clientID = data.kubernetes_secret.keycloak-client-secret-oauth-proxy.data.CLIENT_ID
              clientSecret = data.kubernetes_secret.keycloak-client-secret-oauth-proxy.data.CLIENT_SECRET
              configFile = <<-EOT
                # Provider
                provider = "oidc"
                provider_display_name = "Keycloak"
                oidc_issuer_url = "https://keycloak.${var.domain}/auth/realms/master"
                email_domains  = ["*"]
                scope = "openid profile email"
                cookie_domains = [".${var.domain}"]
                whitelist_domains = [".${var.domain}"]
                pass_authorization_header = true
                pass_access_token = true
                pass_user_headers = true
                set_authorization_header = true
                set_xauthrequest = true
                cookie_refresh = "1m"
                cookie_expire = "30m"
                # cookie_secure = "false"
                # skip_auth_routes=["/health.*"]
                # skip_provider_button="true"
                ssl_insecure_skip_verify = "true"
              EOT
              cookieSecret = "SEVuTitJTGFFRnREcmt4bGxYdk1DZEM0QUNHbm1JSHc="
            }
            ingress = {
              annotations = {
                "cert-manager.io/cluster-issuer" = "letsencrypt-clusterissuer"
                "nginx.ingress.kubernetes.io/proxy-buffer-size" = "16k"
              }
              enabled = true
              hosts = [
                "oauth.${var.domain}",
              ]
              path = "/"
              tls = [
                {
                  hosts = [
                    "oauth.${var.domain}",
                  ]
                  secretName = "oauth.tls"
                },
              ]
            }
          })
        }
        path = ""
        repoURL = "https://oauth2-proxy.github.io/manifests"
        targetRevision = "4.2.0"
      }
      syncPolicy = {
        automated = {
          prune = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }
  # wait_for = {
  #   fields = {
  #     status.health.status = "Healthy"
  #   }
  # }
}
