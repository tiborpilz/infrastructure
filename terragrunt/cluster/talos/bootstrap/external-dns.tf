locals {
  external_dns_namespace = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata   = { name = "external-dns" }
  }

  cloudflare_external_dns_secret = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata   = { name = "cloudflare-api-token", namespace = "external-dns" }
    data       = { token = base64encode(var.cloudflare_api_token) }
  }

  external_dns_manifests = [
    { name = "ns-external-dns", contents = yamlencode(local.external_dns_namespace) },
    { name = "external-dns-secret", contents = yamlencode(local.cloudflare_external_dns_secret) },
    { name = "external-dns", contents = data.helm_template.external_dns.manifest },
  ]
}

data "helm_template" "external_dns" {
  name         = "external-dns"
  namespace    = "external-dns"
  repository   = "https://kubernetes-sigs.github.io/external-dns/"
  chart        = "external-dns"
  version      = var.external_dns_chart_version
  kube_version = var.kubernetes_version

  set {
    name  = "provider.name"
    value = "cloudflare"
  }

  set {
    name  = "env[0].name"
    value = "CF_API_TOKEN"
  }

  set {
    name  = "env[0].valueFrom.secretKeyRef.name"
    value = "cloudflare-api-token"
  }

  set {
    name  = "env[0].valueFrom.secretKeyRef.key"
    value = "token"
  }

  set {
    name  = "sources[0]"
    value = "service"
  }

  set {
    name  = "sources[1]"
    value = "gateway-httproute"
  }
}
