locals {
  gateway_system_namespace = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata   = { name = "gateway-system" }
  }

  cilium_gateway_class = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"
    metadata   = { name = "cilium" }
    spec       = { controllerName = "io.cilium/gateway-controller" }
  }

  gateway = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "public"
      namespace = "gateway-system"
      annotations = {
        "load-balancer.hetzner.cloud/location"                = var.location
        "load-balancer.hetzner.cloud/disable-private-ingress" = "true"
      }
    }
    spec = {
      gatewayClassName = "cilium"
      listeners = [
        {
          name          = "http"
          protocol      = "HTTP"
          port          = 80
          hostname      = "*.${var.domain}"
          allowedRoutes = { namespaces = { from = "Same" } }
        },
        {
          name     = "https"
          protocol = "HTTPS"
          port     = 443
          hostname = "*.${var.domain}"
          tls = {
            mode            = "Terminate"
            certificateRefs = [{ name = "${local.domain_slug}-wildcard-tls", kind = "Secret", group = "" }]
          }
          allowedRoutes = { namespaces = { from = "All" } }
        },
        # git-over-SSH for forgejo / tangled.
        {
          name     = "ssh"
          protocol = "TCP"
          port     = 22
          allowedRoutes = {
            namespaces = { from = "All" }
            kinds      = [{ kind = "TCPRoute" }]
          }
        },
      ]
    }
  }

  https_redirect = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata   = { name = "https-redirect", namespace = "gateway-system" }
    spec = {
      parentRefs = [{ name = "public", namespace = "gateway-system", sectionName = "http" }]
      hostnames  = ["*.${var.domain}"]
      rules = [{
        filters = [{
          type            = "RequestRedirect"
          requestRedirect = { scheme = "https", statusCode = 301 }
        }]
      }]
    }
  }

  # Pre-manifests run BEFORE chart renders so Cilium, cert-manager, etc. can
  # reference Gateway CRDs and the gateway-system namespace.
  gateway_pre_manifests = [
    { name = "ns-gateway-system", contents = yamlencode(local.gateway_system_namespace) },
    { name = "gateway-api-crds", contents = data.http.gateway_api_crds.response_body },
  ]

  # Post-manifests run LAST. cilium-gateway-class is repeated here (also inside
  # the Cilium chart manifest) because CRD registration isn't instant, so the
  # first apply often races. By this point in the manifest stream the CRD is
  # guaranteed registered. Idempotent if Cilium already applied it.
  gateway_post_manifests = [
    { name = "cilium-gateway-class", contents = yamlencode(local.cilium_gateway_class) },
    { name = "gateway", contents = yamlencode(local.gateway) },
    { name = "https-redirect", contents = yamlencode(local.https_redirect) },
  ]
}

data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_version}/experimental-install.yaml"
}
