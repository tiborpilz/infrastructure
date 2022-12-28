resource "kubernetes_manifest" "keycloakclient_keycloak_argocd" {
  depends_on = [kubernetes_manifest.keycloakrealm_keycloak_master]
  manifest = {
    "apiVersion" = "keycloak.org/v1alpha1"
    "kind" = "KeycloakClient"
    "metadata" = {
      "labels" = {
        "realm" = "master"
      }
      "name" = "argocd"
      "namespace" = "keycloak"
    }
    "spec" = {
      "client" = {
        "clientId" = "argocd"
        "protocol" = "openid-connect"
        "protocolMappers" = [
          {
            "config" = {
              "access.token.claim" = "true"
              "claim.name" = "groups"
              "full.path" = "true"
              "id.token.claim" = "true"
              "multivalued" = "true"
              "userinfo.token.claim" = "true"
              "usermodel.clientRoleMapping.clientId" = "argocd"
              "usermodel.clientRoleMapping.rolePrefix" = "argo:"
            }
            "consentRequired" = false
            "name" = "groups"
            "protocol" = "openid-connect"
            "protocolMapper" = "oidc-usermodel-client-role-mapper"
          },
        ]
        "redirectUris" = [
          "https://argocd.${var.domain}/*",
        ]
        "standardFlowEnabled" = true
      }
      "realmSelector" = {
        "matchLabels" = {
          "realm" = "master"
        }
      }
    }
  }
  wait {
    fields = {
      "status.ready" = "true"
    }
  }
}

data "kubernetes_secret" "keycloakclient_keycloak_argocd" {
  depends_on = [kubernetes_manifest.keycloakclient_keycloak_argocd]
  metadata {
    name = "keycloak-client-secret-argocd"
    namespace = "keycloak"
  }
}

output "keycloakclient_keycloak_argocd_client_secret" {
  value = data.kubernetes_secret.keycloakclient_keycloak_argocd.data["CLIENT_SECRET"]
  sensitive = true
}

data "template_file" "argocd_values" {
  template = file("${path.module}/templates/argocd_values.tpl")
  vars = {
    domain = var.domain
    issuer_url = "https://keycloak.${var.domain}/auth/realms/master"
    client_id = data.kubernetes_secret.keycloakclient_keycloak_argocd.data["CLIENT_ID"]
    client_secret = data.kubernetes_secret.keycloakclient_keycloak_argocd.data["CLIENT_SECRET"]
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.16.10"
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
