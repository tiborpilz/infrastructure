data "template_file" "argocd_values" {
  template = file("${path.module}/templates/argocd_values.tpl")
  vars = {
    domain = var.domain
    auth0_domain = var.auth0_domain
    client_id = auth0_client.argocd.client_id
    client_secret = auth0_client.argocd.client_secret
    github_private_key = file(abspath(var.github_private_key_path))
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "3.17.6"
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 600

  set {
    name  = "createCRD"
    value = false
  }

  set {
    name = "helm.versions"
    value = "v3"
  }

  values = [data.template_file.argocd_values.rendered]
}
