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