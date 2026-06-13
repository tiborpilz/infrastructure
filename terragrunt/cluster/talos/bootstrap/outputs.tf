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
        email  = var.admin_email
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

  wildcard_certificate = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata   = { name = "${local.domain_slug}-wildcard-tls", namespace = "gateway-system" }
    spec = {
      secretName = "${local.domain_slug}-wildcard-tls"
      issuerRef  = { name = "letsencrypt-prod", kind = "ClusterIssuer" }
      dnsNames   = ["*.${var.domain}"]
    }
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

  argocd_httproute = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata   = { name = "argocd", namespace = "argocd" }
    spec = {
      parentRefs = [{ name = "public", namespace = "gateway-system", sectionName = "https" }]
      hostnames  = ["argocd.${var.domain}"]
      rules = [{
        backendRefs = [{ name = "argocd-server", port = 80 }]
      }]
    }
  }

  argocd_age_keys_secret = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata   = { name = "age-keys", namespace = "argocd" }
    data       = { "keys.txt" = base64encode(var.argocd_age_key) }
  }

  # ArgoCD uses the HOME env var to locate age keys. Mount the secret at /home/argocd/.age/keys.txt
  # and set HOME=/home/argocd so SOPS can find it automatically.
  argocd_repo_server_patch = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata   = { name = "argocd-repo-server", namespace = "argocd" }
    spec = {
      template = {
        spec = {
          containers = [
            {
              name = "argocd-repo-server"
              env = [
                { name = "HOME", value = "/home/argocd" }
              ]
              volumeMounts = [
                {
                  name      = "age-keys"
                  mountPath = "/home/argocd/.age"
                }
              ]
            }
          ]
          volumes = [
            {
              name = "age-keys"
              secret = {
                secretName = "age-keys"
                items = [
                  {
                    key  = "keys.txt"
                    path = "keys.txt"
                  }
                ]
              }
            }
          ]
        }
      }
    }
  }

}

locals {
  all_manifests = concat(
    [
      for ns_name in sort(keys(local.extra_namespaces)) : {
        name     = "ns-${ns_name}"
        contents = yamlencode(local.extra_namespaces[ns_name])
      }
    ],
    [
      { name = "gateway-api-crds",            contents = data.http.gateway_api_crds.response_body },
      { name = "cilium",                      contents = data.helm_template.cilium.manifest },
      { name = "hcloud-ccm-secret",           contents = yamlencode(local.hcloud_ccm_secret) },
      { name = "hcloud-ccm",                  contents = data.helm_template.hcloud_ccm.manifest },
      { name = "hcloud-csi-secret",           contents = yamlencode(local.hcloud_csi_secret) },
      { name = "hcloud-csi",                  contents = data.helm_template.hcloud_csi.manifest },
      { name = "argocd",                      contents = data.helm_template.argocd.manifest },
      { name = "argocd-age-keys-secret",      contents = yamlencode(local.argocd_age_keys_secret) },
      { name = "argocd-repo-server-patch",    contents = yamlencode(local.argocd_repo_server_patch) },
      { name = "argocd-httproute",            contents = yamlencode(local.argocd_httproute) },
      { name = "cert-manager-secret",         contents = yamlencode(local.cloudflare_cert_manager_secret) },
      { name = "cert-manager",                contents = data.helm_template.cert_manager.manifest },
      { name = "cert-manager-cluster-issuer", contents = yamlencode(local.cluster_issuer) },
      { name = "wildcard-certificate",        contents = yamlencode(local.wildcard_certificate) },
      { name = "external-dns-secret",         contents = yamlencode(local.cloudflare_external_dns_secret) },
      { name = "external-dns",                contents = data.helm_template.external_dns.manifest },
      # GatewayClass is also inside the cilium manifest, but CRD registration
      # isn't instant so it often fails when applied immediately after the CRD
      # manifest. Repeating it here (after 10+ other manifests) ensures the CRD
      # is registered. Idempotent if Cilium's manifest already applied it.
      { name = "cilium-gateway-class",        contents = yamlencode({
        apiVersion = "gateway.networking.k8s.io/v1"
        kind       = "GatewayClass"
        metadata   = { name = "cilium" }
        spec       = { controllerName = "io.cilium/gateway-controller" }
      })},
      { name = "gateway",                     contents = yamlencode(local.gateway) },
      { name = "https-redirect",              contents = yamlencode(local.https_redirect) },
    ],
  )
}

output "inline_manifests" {
  description = "Inline manifests for Talos bootstrap."
  value       = local.all_manifests
}

output "rendered_yaml" {
  description = "All bootstrap manifests concatenated as a multi-document YAML string. Write to a file for inspection."
  value       = join("\n---\n", [for m in local.all_manifests : "# ${m.name}\n${m.contents}"])
}
