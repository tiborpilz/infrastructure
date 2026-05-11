locals {
  namespace    = "${var.name}-auth"
  display_name = coalesce(var.display_name, title(var.name))
  subdomain    = coalesce(var.subdomain, var.name)
  hostname     = "${local.subdomain}.${var.domain}"
  app_url      = "https://${local.hostname}"

  oidc_client_id    = var.name
  oidc_redirect_uri = "${local.app_url}/oauth2/callback"
  oidc_issuer_url   = "${var.authentik_url}/application/o/${var.name}/"

  upstream_url = "http://${var.upstream_service_name}.${var.upstream_service_namespace}.svc.cluster.local:${var.upstream_service_port}"
}

resource "terraform_data" "authentik_gate" {
  input = var.authentik_ready
}

resource "terraform_data" "authentik_config_gate" {
  input = var.authentik_config_ready
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = local.namespace
    labels = {
      "managed-by" = "terragrunt"
    }
  }
}

resource "random_password" "oidc_client_secret" {
  length  = 48
  special = false
}

# oauth2-proxy expects a 32-byte cookie secret (AES-256 key). Generate raw
# alphanumeric — the chart accepts either raw 32-byte strings or base64.
resource "random_password" "cookie_secret" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "oauth2_proxy" {
  metadata {
    name      = "oauth2-proxy-secrets"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  data = {
    client-id     = local.oidc_client_id
    client-secret = random_password.oidc_client_secret.result
    cookie-secret = random_password.cookie_secret.result
  }
}

data "authentik_flow" "default_authorization" {
  slug = "default-provider-authorization-implicit-consent"

  depends_on = [terraform_data.authentik_gate]
}

data "authentik_flow" "default_authentication" {
  slug = "default-authentication-flow"

  depends_on = [terraform_data.authentik_gate]
}

data "authentik_flow" "default_invalidation" {
  slug = "default-provider-invalidation-flow"

  depends_on = [terraform_data.authentik_gate]
}

data "authentik_certificate_key_pair" "default" {
  name = "authentik Self-signed Certificate"

  depends_on = [terraform_data.authentik_gate]
}

data "authentik_property_mapping_provider_scope" "openid" {
  name = "authentik default OAuth Mapping: OpenID 'openid'"

  depends_on = [terraform_data.authentik_gate]
}

data "authentik_property_mapping_provider_scope" "profile" {
  name = "authentik default OAuth Mapping: OpenID 'profile'"

  depends_on = [terraform_data.authentik_gate]
}

data "authentik_property_mapping_provider_scope" "email" {
  name = "authentik default OAuth Mapping: OpenID 'email'"

  depends_on = [terraform_data.authentik_gate]
}

resource "authentik_provider_oauth2" "this" {
  name          = var.name
  client_id     = local.oidc_client_id
  client_secret = random_password.oidc_client_secret.result

  authorization_flow  = data.authentik_flow.default_authorization.id
  authentication_flow = data.authentik_flow.default_authentication.id
  invalidation_flow   = data.authentik_flow.default_invalidation.id

  signing_key = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = local.oidc_redirect_uri
    },
  ]

  property_mappings = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.profile.id,
    data.authentik_property_mapping_provider_scope.email.id,
  ]

  sub_mode = "hashed_user_id"
}

resource "authentik_application" "this" {
  name              = local.display_name
  slug              = var.name
  protocol_provider = authentik_provider_oauth2.this.id
  meta_launch_url   = local.app_url
}

# Lookup admin groups created elsewhere (authentik-config module). The gate
# guarantees those groups exist before this lookup runs.
data "authentik_group" "admins" {
  for_each = toset(var.admin_groups)

  name = each.value

  depends_on = [terraform_data.authentik_config_gate]
}

# Restrict who can authenticate to this application. With at least one group
# binding, authentik's default `any`-mode policy engine denies any user not
# in one of the bound groups — independent of oauth2-proxy. With an empty
# `admin_groups`, no binding is created and any authenticated authentik user
# may access.
resource "authentik_policy_binding" "admins" {
  for_each = toset(var.admin_groups)

  target = authentik_application.this.uuid
  group  = data.authentik_group.admins[each.value].id
  order  = 0
}

locals {
  oauth2_proxy_values = yamlencode({
    config = {
      existingSecret = kubernetes_secret.oauth2_proxy.metadata[0].name
    }

    extraArgs = {
      provider                    = "oidc"
      "oidc-issuer-url"           = local.oidc_issuer_url
      "redirect-url"              = local.oidc_redirect_uri
      upstream                    = local.upstream_url
      "email-domain"              = "*"
      # Trust X-Forwarded-* headers from Cilium Gateway. Without this,
      # cookie-secure=true blocks the session cookie because the in-cluster
      # connection from Envoy is plain HTTP and oauth2-proxy treats the
      # request as insecure — causing an endless redirect loop after login.
      "reverse-proxy"             = "true"
      "cookie-secure"             = "true"
      "cookie-domain"             = local.hostname
      # Lax lets the CSRF cookie ride along on the top-level GET back from
      # authentik. Default is unset (browser-dependent) and intermittently
      # drops the cookie, triggering "CSRF token mismatch" at /oauth2/callback.
      "cookie-samesite"           = "lax"
      "whitelist-domain"          = local.hostname
      # Bind the auth request to a per-session secret (PKCE). authentik
      # supports S256; oauth2-proxy logs a warning if it isn't enabled.
      "code-challenge-method"     = "S256"
      "pass-authorization-header" = "true"
      "pass-access-token"         = "true"
      "pass-user-headers"         = "true"
      "set-authorization-header"  = "true"
      "set-xauthrequest"          = "true"
      "skip-provider-button"      = "false"
      # authentik doesn't emit `email_verified: true` reliably in the id_token,
      # and oauth2-proxy refuses logins otherwise. Authentik IS the source of
      # truth for these accounts, so the verified flag is meaningless.
      "insecure-oidc-allow-unverified-email" = "true"
      scope                                  = "openid profile email"
    }

    service = {
      portNumber = 80
    }

    ingress = {
      enabled = false
    }
  })
}

resource "kubectl_manifest" "argo_app" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "${var.name}-oauth2-proxy"
      namespace = var.argocd_namespace
    }
    spec = {
      project = "platform"
      source = {
        repoURL        = "https://oauth2-proxy.github.io/manifests"
        chart          = "oauth2-proxy"
        targetRevision = var.oauth2_proxy_chart_version
        helm = {
          releaseName = "oauth2-proxy"
          values      = local.oauth2_proxy_values
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.this.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "ServerSideApply=true",
          "CreateNamespace=false",
        ]
      }
    }
  })

  depends_on = [
    kubernetes_secret.oauth2_proxy,
    authentik_application.this,
  ]
}

# Cilium's gatewayAPI controller resolves HTTPRoute backendRefs at create
# time. Applying the route before Argo has rolled out the oauth2-proxy
# Service leaves the route stuck with `ResolvedRefs=False, Service ... not
# found` — and the controller's Service watcher does not re-reconcile
# reliably. Block here until the Service actually exists.
resource "terraform_data" "wait_for_oauth2_proxy_svc" {
  triggers_replace = {
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      set -euo pipefail
      ns="${kubernetes_namespace.this.metadata[0].name}"
      for i in $(seq 1 60); do
        if kubectl -n "$ns" get svc oauth2-proxy >/dev/null 2>&1; then
          echo "$ns/oauth2-proxy ready"
          exit 0
        fi
        echo "waiting for $ns/oauth2-proxy (attempt $i/60)..."
        sleep 5
      done
      echo "$ns/oauth2-proxy never appeared after 5 minutes" >&2
      exit 1
    EOT
  }

  depends_on = [kubectl_manifest.argo_app]
}

resource "kubectl_manifest" "httproute" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = var.name
      namespace = kubernetes_namespace.this.metadata[0].name
    }
    spec = {
      parentRefs = [
        {
          name      = var.gateway_name
          namespace = var.gateway_namespace
        }
      ]
      hostnames = [local.hostname]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          backendRefs = [
            {
              name = "oauth2-proxy"
              port = 80
            }
          ]
        }
      ]
    }
  })

  depends_on = [terraform_data.wait_for_oauth2_proxy_svc]
}
