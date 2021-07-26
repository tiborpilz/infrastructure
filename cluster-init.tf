provider "helm" {
  kubernetes {
    host = rke_cluster.cluster.api_server_url
    client_certificate = rke_cluster.cluster.client_cert
    client_key = rke_cluster.cluster.client_key
    cluster_ca_certificate = rke_cluster.cluster.ca_crt
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "3.6.8"
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [
    file("./applications/argocd/values.yaml")
  ]
}
