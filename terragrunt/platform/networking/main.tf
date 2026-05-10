locals {
  argocd_namespace = "argocd"
  domain_slug = replace(var.domain, ".", "-")
}

resource "terraform_data" "argocd_gate" {
  input = var.argocd_ready
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
    labels = {
      "managed-by" = "terragrunt"
    }
  }
}

resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = "external-dns"
    labels = {
      "managed-by" = "terragrunt"
    }
  }
}

resource "kubernetes_namespace" "gateway_system" {
  metadata {
    name = "gateway-system"
    labels = {
      "managed-by" = "terragrunt"
    }
  }
}

# ---------------------------------------------------------------------------
# Cloudflare API token — Secret in cert-manager + external-dns namespaces.
# The token itself comes via TF_VAR_cloudflare_api_token; lives in TF state.
# Migrate to SOPS in M2.
# ---------------------------------------------------------------------------

resource "kubernetes_secret" "cloudflare_token_cert_manager" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = kubernetes_namespace.cert_manager.metadata[0].name
  }

  data = {
    token = var.cloudflare_api_token
  }
}

resource "kubernetes_secret" "cloudflare_token_external_dns" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = kubernetes_namespace.external_dns.metadata[0].name
  }

  data = {
    token = var.cloudflare_api_token
  }
}

# ---------------------------------------------------------------------------
# Argo CD Applications — TF owns the inventory, Argo runs the reconciliation.
# Using kubectl_manifest to apply the Application CRs directly (avoids
# pulling in the argocd Terraform provider with its API connection setup).
# ---------------------------------------------------------------------------

resource "kubectl_manifest" "argo_app_cert_manager" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "cert-manager"
      namespace = local.argocd_namespace
    }
    spec = {
      project = "platform"
      source = {
        repoURL        = "https://charts.jetstack.io"
        chart          = "cert-manager"
        targetRevision = var.cert_manager_chart_version
        helm = {
          values = var.cert_manager_values
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.cert_manager.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "ServerSideApply=true",
        ]
      }
    }
  })

  depends_on = [
    terraform_data.argocd_gate,
    kubernetes_secret.cloudflare_token_cert_manager,
  ]
}

resource "kubectl_manifest" "argo_app_external_dns" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "external-dns"
      namespace = local.argocd_namespace
    }
    spec = {
      project = "platform"
      source = {
        repoURL        = "https://kubernetes-sigs.github.io/external-dns/"
        chart          = "external-dns"
        targetRevision = var.external_dns_chart_version
        helm = {
          values = var.external_dns_values
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.external_dns.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "ServerSideApply=true",
        ]
      }
    }
  })

  depends_on = [
    terraform_data.argocd_gate,
    kubernetes_secret.cloudflare_token_external_dns,
  ]
}

# ---------------------------------------------------------------------------
# Public Gateway. cert-manager auto-issues a wildcard cert via the annotation
# (uses the letsencrypt-prod ClusterIssuer that ships in the cert-manager
# Application's extraObjects).
#
# The Gateway is in gateway-system; HTTPRoute resources in app namespaces
# attach via parentRefs.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# HTTPRoute for the Argo CD UI. Lives here (not in platform) because the
# Gateway is owned by this module and platform doesn't depend on networking
# — putting the route here avoids a dependency cycle. argocd-server runs
# with --insecure (set in platform's chart values), so the Gateway speaks
# HTTP to the backend and handles TLS at the edge via the wildcard cert.
# ---------------------------------------------------------------------------

resource "kubectl_manifest" "httproute_argocd" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "argocd"
      namespace = "argocd"
    }
    spec = {
      parentRefs = [
        {
          name      = "public"
          namespace = kubernetes_namespace.gateway_system.metadata[0].name
        }
      ]
      hostnames = ["argocd.${var.domain}"]
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
              name = "argocd-server"
              port = 80
            }
          ]
        }
      ]
    }
  })
}

# ---------------------------------------------------------------------------
# Wildcard DNS catch-all. Points *.<domain> at the Hetzner LB the Gateway
# Service got allocated. New apps work the moment their HTTPRoute is in
# place — no waiting on external-dns + DNS propagation.
#
# Specific A/AAAA records that external-dns publishes per HTTPRoute take
# precedence (DNS spec: more-specific labels win), so this only ever serves
# subdomains that don't have an explicit external-dns record. If the LB is
# ever recreated with a new IP, re-running terragrunt apply on this layer
# updates the wildcard. external-dns isn't aware of the wildcard and won't
# touch it.
# ---------------------------------------------------------------------------

data "cloudflare_zone" "this" {
  name = var.domain
}

# Wait for the Hetzner LB to actually have an IP before we try to publish
# it. This data source re-reads on every apply, so a recreated LB rolls in
# automatically.
data "kubernetes_service" "gateway" {
  metadata {
    name      = "cilium-gateway-public"
    namespace = kubernetes_namespace.gateway_system.metadata[0].name
  }

  depends_on = [kubectl_manifest.public_gateway]
}

locals {
  lb_ingress      = data.kubernetes_service.gateway.status[0].load_balancer[0].ingress
  lb_ipv4_ingress = [for ing in local.lb_ingress : ing.ip if can(regex("^[0-9.]+$", ing.ip))]
  lb_ipv6_ingress = [for ing in local.lb_ingress : ing.ip if can(regex(":", ing.ip))]
}

resource "cloudflare_record" "wildcard_a" {
  count = length(local.lb_ipv4_ingress) > 0 ? 1 : 0

  zone_id = data.cloudflare_zone.this.id
  name    = "*"
  type    = "A"
  content = local.lb_ipv4_ingress[0]
  ttl     = 1 # 1 = Cloudflare "auto" (5 min for DNS-only)
  proxied = false
  comment = "Catch-all → Hetzner LB."
}

resource "cloudflare_record" "wildcard_aaaa" {
  count = length(local.lb_ipv6_ingress) > 0 ? 1 : 0

  zone_id = data.cloudflare_zone.this.id
  name    = "*"
  type    = "AAAA"
  content = local.lb_ipv6_ingress[0]
  ttl     = 1
  proxied = false
  comment = "Catch-all → Hetzner LB IPv6."
}

resource "kubectl_manifest" "public_gateway" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "public"
      namespace = kubernetes_namespace.gateway_system.metadata[0].name
      annotations = {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      }
    }
    spec = {
      gatewayClassName = "cilium"

      listeners = [
        {
          name     = "https"
          protocol = "HTTPS"
          port     = 443
          hostname = "*.${var.domain}"
          tls = {
            mode = "Terminate"
            certificateRefs = [
              {
                name  = "${local.domain_slug}-wildcard-tls"
                kind  = "Secret"
                group = ""
              }
            ]
          }
          allowedRoutes = {
            namespaces = {
              from = "All"
            }
          }
        }
      ]
    }
  })

  # Apply after cert-manager so the cluster-issuer annotation is meaningful.
  # cert-manager will reconcile the cert once both Gateway + ClusterIssuer
  # exist; ordering here just minimizes "pending" noise.
  depends_on = [
    kubectl_manifest.argo_app_cert_manager,
  ]
}
