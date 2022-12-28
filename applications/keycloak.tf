# data "kustomization" "keycloak" {
#     provider = kustomization
#     path = "kustomizations/keycloak"
# }

# resource "kustomization_resource" "keycloak" {
#     provider = kustomization
#     for_each = data.kustomization.keycloak.ids
#     manifest = data.kustomization.keycloak.manifests[each.value]
# }

resource "kubernetes_manifest" "keycloak_keycloak" {
  manifest = {
    "apiVersion" = "keycloak.org/v1alpha1"
    "kind" = "Keycloak"
    "metadata" = {
      "name" = "keycloak"
      "namespace" = "keycloak"
      "labels" = {
        "app" = "sso"
      }
    }
    "spec" = {
      "instances" = "1"
      "externalAccess" = {
        "enabled" = "True"
        "host" = "keycloak.bababourbaki.dev"
        "tlsTermination" = "reencrypt"
      }
    }
  }
  wait {
    fields = {
      "status.ready" = "true"
    }
  }
}

resource "kubernetes_manifest" "keycloakrealm_keycloak_master" {
  depends_on = [kubernetes_manifest.keycloak_keycloak]
  manifest = {
    "apiVersion" = "keycloak.org/v1alpha1"
    "kind" = "KeycloakRealm"
    "metadata" = {
      "name" = "master"
      "namespace" = "keycloak"
      "labels" = {
        "realm" = "master"
      }
    }
    "spec" = {
      "instanceSelector" = {
        "matchLabels" = {
          "app" = "sso"
        }
      }
      "realm" = {
        "displayName" = "Master"
        "enabled" = true
        "id" = "master"
        "realm" = "master"
      }
    }
  }
  wait {
    fields = {
      "status.ready" = "true"
    }
  }
}

resource "kubernetes_manifest" "keycloakuser_tibor" {
  depends_on = [kubernetes_manifest.keycloakrealm_keycloak_master]
  manifest = {
    "apiVersion" = "keycloak.org/v1alpha1"
    "kind" = "KeycloakUser"
    "metadata" = {
      "name" = "tibor"
      "namespace" = "keycloak"
      "labels" = {
        "app" = "sso"
      }
    }
    "spec" = {
      "realmSelector" = {
        "matchLabels" = {
          "realm" = "master"
        }
      }
      "user" = {
        "credentials" = [
          {
            "type" = "password"
            "value" = "testpw12345"
          },
        ]
        "email" = "tibor@pilz.berlin"
        "emailVerified" = true
        "enabled" = true
        "firstName" = "Tibor"
        "lastName" = "Pilz"
        "realmRoles" = [
          "admin",
        ]
        "username" = "tibor"
      }
    }
  }
  computed_fields = ["spec.user.id"]
  wait {
    fields = {
      "status.phase" = "reconciled"
      "spec.user.id" = "^([a-z0-9]+(-|$)){1,8}"
    }
  }
}

resource "kubernetes_cluster_role_binding" "oidc-cluster-admin" {
    metadata {
        name = "oidc-cluster-admin"
    }

    role_ref {
        api_group = "rbac.authorization.k8s.io"
        kind      = "ClusterRole"
        name      = "cluster-admin"
    }

    subject {
        kind      = "User"
        name      = "https://keycloak.${var.domain}/auth/realms/master#${kubernetes_manifest.keycloakuser_tibor.object.spec.user.id}"
        api_group = "rbac.authorization.k8s.io"
    }
}

resource "kubernetes_ingress_v1" "keycloak" {
  metadata {
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-clusterissuer"
      "external-dns.alpha.kubernetes.io/hostname" = "keycloak.bababourbaki.dev"
      "kubernetes.io/ingress.class" = "nginx"
      "kubernetes.io/tls-acme" = "true"
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
      "nginx.ingress.kubernetes.io/server-snippet" = <<-EOT
        location ~* "^/auth/realms/master/metrics" {
          return 301 /auth/realms/master;
        }
        EOT
    }
    labels = {
      "app" = "keycloak"
    }
    name = "keycloak"
    namespace = "keycloak"
  }

  spec {
    rule {
      http {
        path {
          backend {
            service {
              name = "keycloak"
              port {
                number = 8443
              }
            }
          }

          path = "/"
          path_type = "ImplementationSpecific"
        }
      }
    }
    tls {
      hosts = [
        "keycloak.bababourbaki.dev"
      ]
      secret_name = "keycloak-tls"
    }
  }
}

resource "kubernetes_manifest" "keycloakclient_keycloak_kubernetes" {
  depends_on = [kubernetes_manifest.keycloakrealm_keycloak_master]
  manifest = {
    "apiVersion" = "keycloak.org/v1alpha1"
    "kind" = "KeycloakClient"
    "metadata" = {
      "labels" = {
        "realm" = "master"
      }
      "name" = "kubernetes"
      "namespace" = "keycloak"
    }
    "spec" = {
      "client" = {
        "clientId" = "kubernetes"
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
              "usermodel.clientRoleMapping.clientId" = "kubernetes"
              "usermodel.clientRoleMapping.rolePrefix" = "kubernetes:"
            }
            "consentRequired" = false
            "name" = "groups"
            "protocol" = "openid-connect"
            "protocolMapper" = "oidc-usermodel-client-role-mapper"
          },
        ]
        "redirectUris" = [
          "http://localhost:8000",
          "http://localhost:18000",
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
}
