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
    { name = "external-dns-crd", contents = file("${path.module}/files/dnsendpoints.externaldns.k8s.io.yaml") },
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

  values = [file("${path.module}/files/external-dns-values.yaml")]
}
