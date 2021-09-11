resource "helm_release" "ingress-nginx" {
  name = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart = "ingress-nginx"
  version = "3.34.0"
  namespace = "ingress-nginx"
  create_namespace = true
  timeout = 600
}

