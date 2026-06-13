locals {
  extra_namespaces = {
    argocd = {
      apiVersion = "v1"
      kind       = "Namespace"
      metadata   = { name = "argocd" }
    }
    cert_manager = {
      apiVersion = "v1"
      kind       = "Namespace"
      metadata   = { name = "cert-manager" }
    }
    external_dns = {
      apiVersion = "v1"
      kind       = "Namespace"
      metadata   = { name = "external-dns" }
    }
    gateway_system = {
      apiVersion = "v1"
      kind       = "Namespace"
      metadata   = { name = "gateway-system" }
    }
    cnpg_system = {
      apiVersion = "v1"
      kind       = "Namespace"
      metadata   = { name = "cnpg-system" }
    }
    authentik = {
      apiVersion = "v1"
      kind       = "Namespace"
      metadata   = { name = "authentik" }
    }
    hcloud_csi = {
      apiVersion = "v1"
      kind       = "Namespace"
      metadata = {
        name = "hcloud-csi"
        labels = {
          "pod-security.kubernetes.io/enforce" = "privileged"
          "pod-security.kubernetes.io/audit"   = "privileged"
          "pod-security.kubernetes.io/warn"    = "privileged"
        }
      }
    }
  }

  hcloud_ccm_secret = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata   = { name = "hcloud", namespace = "kube-system" }
    data = {
      token   = base64encode(var.hcloud_token)
      network = base64encode(var.network_name)
    }
  }

  hcloud_csi_secret = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata   = { name = "hcloud", namespace = "hcloud-csi" }
    data       = { token = base64encode(var.hcloud_token) }
  }

  cloudflare_cert_manager_secret = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata   = { name = "cloudflare-api-token", namespace = "cert-manager" }
    data       = { token = base64encode(var.cloudflare_api_token) }
  }

  cloudflare_external_dns_secret = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata   = { name = "cloudflare-api-token", namespace = "external-dns" }
    data       = { token = base64encode(var.cloudflare_api_token) }
  }

  cluster_issuer = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata   = { name = "letsencrypt-prod" }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.acme_email
        privateKeySecretRef = { name = "letsencrypt-prod-account-key" }
        solvers = [{
          dns01 = {
            cloudflare = {
              apiTokenSecretRef = { name = "cloudflare-api-token", key = "token" }
            }
          }
        }]
      }
    }
  }

  domain_slug = replace(var.domain, ".", "-")

  gateway = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "public"
      namespace = "gateway-system"
      annotations = {
        "cert-manager.io/cluster-issuer"                      = "letsencrypt-prod"
        "external-dns.alpha.kubernetes.io/hostname"           = "*.${var.domain}"
        "load-balancer.hetzner.cloud/location"                = var.location
        "load-balancer.hetzner.cloud/disable-private-ingress" = "true"
      }
    }
    spec = {
      gatewayClassName = "cilium"
      listeners = [
        {
          name     = "http"
          protocol = "HTTP"
          port     = 80
          hostname = "*.${var.domain}"
          allowedRoutes = { namespaces = { from = "Same" } }
        },
        {
          name     = "https"
          protocol = "HTTPS"
          port     = 443
          hostname = "*.${var.domain}"
          tls = {
            mode = "Terminate"
            certificateRefs = [{ name = "${local.domain_slug}-wildcard-tls", kind = "Secret", group = "" }]
          }
          allowedRoutes = { namespaces = { from = "All" } }
        },
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

  authentik_bootstrap_secret = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "authentik-bootstrap"
      namespace = "authentik"
    }
    data = {
      AUTHENTIK_SECRET_KEY                = base64encode(random_password.authentik_secret_key.result)
      AUTHENTIK_BOOTSTRAP_PASSWORD        = base64encode(random_password.authentik_admin_password.result)
      AUTHENTIK_BOOTSTRAP_TOKEN__TOKEN    = base64encode(random_password.authentik_bootstrap_token.result)
    }
  }
}

output "inline_manifests" {
  description = "Inline manifests for Talos bootstrap."
  value = concat(
    [
      for ns_name in sort(keys(local.extra_namespaces)) : {
        name     = "ns-${ns_name}"
        contents = yamlencode(local.extra_namespaces[ns_name])
      }
    ],
    [
      { name = "cilium",                        contents = data.helm_template.cilium.manifest },
      { name = "hcloud-ccm-secret",             contents = yamlencode(local.hcloud_ccm_secret) },
      { name = "hcloud-ccm",                    contents = data.helm_template.hcloud_ccm.manifest },
      { name = "hcloud-csi-secret",             contents = yamlencode(local.hcloud_csi_secret) },
      { name = "hcloud-csi",                    contents = data.helm_template.hcloud_csi.manifest },
      { name = "argocd",                        contents = data.helm_template.argocd.manifest },
      { name = "cert-manager-secret",           contents = yamlencode(local.cloudflare_cert_manager_secret) },
      { name = "cert-manager",                  contents = data.helm_template.cert_manager.manifest },
      { name = "cert-manager-cluster-issuer",   contents = yamlencode(local.cluster_issuer) },
      { name = "external-dns-secret",           contents = yamlencode(local.cloudflare_external_dns_secret) },
      { name = "external-dns",                  contents = data.helm_template.external_dns.manifest },
      { name = "cnpg-operator",                 contents = data.helm_template.cnpg.manifest },
      { name = "authentik-bootstrap-secret",    contents = yamlencode(local.authentik_bootstrap_secret) },
      { name = "authentik",                     contents = data.helm_template.authentik.manifest },
      { name = "gateway",                       contents = yamlencode(local.gateway) },
      { name = "https-redirect",                contents = yamlencode(local.https_redirect) },
    ],
  )
}
