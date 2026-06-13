locals {
  cert_manager_namespace = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata   = { name = "cert-manager" }
  }

  cloudflare_cert_manager_secret = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata   = { name = "cloudflare-api-token", namespace = "cert-manager" }
    data       = { token = base64encode(var.cloudflare_api_token) }
  }

  cluster_issuer = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata   = { name = "letsencrypt-prod" }
    spec = {
      acme = {
        server              = "https://acme-v02.api.letsencrypt.org/directory"
        email               = var.admin_email
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

  cert_manager_manifests = [
    { name = "ns-cert-manager", contents = yamlencode(local.cert_manager_namespace) },
    { name = "cert-manager-secret", contents = yamlencode(local.cloudflare_cert_manager_secret) },
    { name = "cert-manager", contents = data.helm_template.cert_manager.manifest },
    { name = "cert-manager-cluster-issuer", contents = yamlencode(local.cluster_issuer) },
    { name = "wildcard-certificate", contents = yamlencode(local.wildcard_certificate) },
  ]
}

data "helm_template" "cert_manager" {
  name         = "cert-manager"
  namespace    = "cert-manager"
  repository   = "https://charts.jetstack.io"
  chart        = "cert-manager"
  version      = var.cert_manager_chart_version
  kube_version = var.kubernetes_version

  set {
    name  = "crds.enabled"
    value = "true"
  }
}
