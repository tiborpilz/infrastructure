variable "auth0_domain" {}
variable "auth0_client_id" {}
variable "auth0_client_secret" {}

provider "auth0" {
  domain = var.auth0_domain
  client_id = var.auth0_client_id
  client_secret = var.auth0_client_secret
}

provider "helm" {
  kubernetes {
    host = rke_cluster.cluster.api_server_url
    client_certificate = rke_cluster.cluster.client_cert
    client_key = rke_cluster.cluster.client_key
    cluster_ca_certificate = rke_cluster.cluster.ca_crt
  }
}

resource "helm_release" "ingress-nginx" {
  name = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart = "ingress-nginx"
  version = "3.34.0"
  namespace = "ingress-nginx"
  create_namespace = true
  timeout = 600
}

resource "auth0_client" "argocd" {
  name = "argocd"
  callbacks = ["https://argocd.tiborpilz.dev/auth/callback"]
  initiate_login_uri = "https://argocd.tiborpilz.dev/login"
  app_type = "regular_web"
  oidc_conformant = true

  jwt_configuration {
    alg = "RS256"
  }
}

resource "auth0_rule" "argocd" {
  name = "empty-rule"
  enabled = true
  script = <<EOF
    function (user, context, callback) {
    var namespace = 'https://argocd.tiborpilz.dev/claims/';
    context.idToken[namespace + "groups"] = user.groups;
    callback(null, user, context);
  }
  EOF
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

  /* settls { */
  /*   name  = "createCRD" */
  /*   value = false */
  /* } */

  /* set { */
  /*   name = "helm.versions" */
  /*   value = "v3" */
  /* } */

  values = [file("./applications/argocd/values.yaml")]
  /* values = [ */
  /*   <<EOF */
  /*   server: */
  /*     ingress: */
  /*       enabled: true */
  /*       hosts: */
  /*         - argocd.${var.domain} */
  /*       tls: */
  /*         - hosts: */
  /*             - argocd.${var.domain} */
  /*           secretName: argocd-secret */
  /*       annotations: */
  /*         cert-manager.io/cluster-issuer: letsencrypt-clusterissuer */
  /*         kubernetes.io/ingress.class: nginx */
  /*         kubernetes.io/tls-acme: 'true' */
  /*         nginx.ingress.kubernetes.io/ssl-passthrough: 'true' */
  /*         nginx.ingress.kubernetes.io/backend-protocol: 'HTTPS' */
  /*       https: true */
  /*     configEnabled: true */
  /*     config: */
  /*       url: https://argocd.${var.domain} */
  /*       application.instanceLabelKey: argocd.argoproj.io/instance */
  /*       oidc.config: | */
  /*         name: Auth0 */
  /*         issuer: ${var.auth0_domain}/ */
  /*         clientID: ${auth0_client.argocd.client_id} */
  /*         clientSecret: ${auth0_client.argocd.client_secret} */
  /*         requestedIDTokenClaims: */
  /*           groups: */
  /*             essential: true */
  /*         requestedScopes: */
  /*         - openid */
  /*         - profile */
  /*         - email */
  /*         - 'https://argocd.${var.domain}/claims/groups' */
  /*     rbacConfig: */
  /*       policy.csv: | */
  /*         g, argo-admins, role:admin */
  /*       scopes: '[https://argocd.${var.domain}/claims/groups, email]' */
  /*   EOF */
  /* ] */
}
