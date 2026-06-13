locals {
  domain_slug = replace(var.domain, ".", "-")
}

resource "kubernetes_namespace" "gateway_system" {
  metadata {
    name = "gateway-system"
    labels = {
      "managed-by" = "terragrunt"
    }
  }
}

data "cloudflare_zone" "this" {
  name = var.domain
}

# We need to wait a bit for Hetzner CCM to populate the external ID.
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

      infrastructure = {
        annotations = {
          "load-balancer.hetzner.cloud/location"                = var.hcloud_location
          "load-balancer.hetzner.cloud/disable-private-ingress" = "true"
        }
      }

      listeners = [
        {
          name     = "http"
          protocol = "HTTP"
          port     = 80
          hostname = "*.${var.domain}"
          allowedRoutes = {
            namespaces = {
              from = "Same"
            }
          }
        },
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
        },
        # git-over-SSH for forgejo (or tangled 👀)
        {
          name     = "ssh"
          protocol = "TCP"
          port     = 22
          allowedRoutes = {
            namespaces = {
              from = "All"
            }
            kinds = [
              {
                kind = "TCPRoute"
              }
            ]
          }
        }
      ]
    }
  })
}

resource "kubectl_manifest" "httproute_https_redirect" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "https-redirect"
      namespace = kubernetes_namespace.gateway_system.metadata[0].name
    }
    spec = {
      parentRefs = [
        {
          name        = "public"
          namespace   = kubernetes_namespace.gateway_system.metadata[0].name
          sectionName = "http"
        }
      ]
      hostnames = ["*.${var.domain}"]
      rules = [
        {
          filters = [
            {
              type = "RequestRedirect"
              requestRedirect = {
                scheme     = "https"
                statusCode = 301
              }
            }
          ]
        }
      ]
    }
  })

  depends_on = [kubectl_manifest.public_gateway]
}

