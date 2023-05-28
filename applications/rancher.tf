resource "helm_release" "rancher" {
  name             = "rancher"
  repository       = "https://releases.rancher.com/server-charts/latest"
  chart            = "rancher"
  version          = "2.7.3"
  namespace        = "cattle-system"
  create_namespace = true
  values = [yamlencode({
    hostname = "rancher.${var.domain}"
    ingress = {
      tls = {
        source = "letsEncrypt"
      }
      extraAnnotations = {
        "kubernetes.io/ingress.class" = "nginx"
      }
    }
    letsEncrypt = {
      email = var.email
      ingress = {
        class = "nginx"
      }
    }
  })]
}

provider "rancher2" {
  alias     = "bootstrap"
  api_url   = "https://rancher.${var.domain}"
  bootstrap = true
}

resource "rancher2_bootstrap" "admin" {
  provider  = rancher2.bootstrap
  password  = "admin"
  telemetry = false
}

provider "rancher2" {
  alias     = "admin"
  api_url   = rancher2_bootstrap.admin.url
  token_key = rancher2_bootstrap.admin.token
  insecure  = true
}
