locals {
  argocd_namespace = "argocd"
  domain_slug      = replace(var.domain, ".", "-")
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

# Hetzner CCM populates the Service's external IP ~30s after Cilium creates
# it. kubectl_manifest.public_gateway returns before that hop completes, so
# the wildcard A/AAAA below would otherwise read an empty ingress list.
resource "terraform_data" "wait_for_gateway_lb" {
  triggers_replace = {
    gateway_uid = kubectl_manifest.public_gateway.uid
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${var.kubeconfig_path}"
      ns="${kubernetes_namespace.gateway_system.metadata[0].name}"
      svc="cilium-gateway-public"
      for i in $(seq 1 60); do
        ip=$(kubectl -n "$ns" get svc "$svc" \
          -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
        if [ -n "$ip" ]; then
          echo "Gateway LB has address $ip"
          exit 0
        fi
        echo "waiting for Hetzner LB on $ns/$svc (attempt $i/60)..."
        sleep 5
      done
      echo "Gateway LB never received an address after 5 minutes" >&2
      kubectl -n "$ns" get svc "$svc" -o yaml >&2 || true
      exit 1
    EOT
  }
}

data "kubernetes_service" "gateway" {
  metadata {
    name      = "cilium-gateway-public"
    namespace = kubernetes_namespace.gateway_system.metadata[0].name
  }

  depends_on = [terraform_data.wait_for_gateway_lb]
}

locals {
  lb_ingress      = data.kubernetes_service.gateway.status[0].load_balancer[0].ingress
  lb_ipv4_ingress = [for ing in local.lb_ingress : ing.ip if can(regex("^[0-9.]+$", ing.ip))]
  lb_ipv6_ingress = [for ing in local.lb_ingress : ing.ip if can(regex(":", ing.ip))]
}

resource "cloudflare_record" "wildcard_a" {
  zone_id = data.cloudflare_zone.this.id
  name    = "*"
  type    = "A"
  content = local.lb_ipv4_ingress[0]
  ttl     = 1 # 1 = Cloudflare "auto" (5 min for DNS-only)
  proxied = false
  comment = "Catch-all → Hetzner LB."
}

resource "cloudflare_record" "wildcard_aaaa" {
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

      # Hetzner CCM requires `location` (or `network-zone`) to provision the
      # LB. `disable-private-ingress` keeps the LB's private 10.x IP out of
      # status.loadBalancer.ingress so external-dns doesn't publish it.
      infrastructure = {
        annotations = {
          "load-balancer.hetzner.cloud/location"                = var.hcloud_location
          "load-balancer.hetzner.cloud/disable-private-ingress" = "true"
        }
      }

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
