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
        "displayName" = "Baba Bourbaki"
        "displayNameHtml" = "<div class=\"kc-logo-text\"><span>Baba Bourbaki</span></div>"
        "enabled" = true
        "id" = "master"
        "realm" = "master"
        "clientScopes" = [
          {
            "name" = "testScope"
            "protocol" = "openid-connect"
            "protocolMappers" = [{
              "config" = {
                "access.token.claim" = "true"
                "claim.name" = "groups"
                "full.path" = "true"
                "id.token.claim" = "true"
                "userinfo.token.claim" = "true"
              }
              "name" = "groups"
              "protocol" = "openid-connect"
              "protocolMapper" = "oidc-group-membership-mapper"
            }]
          }
        ]
      }
    }
  }
  wait {
    fields = {
      "status.ready" = "true"
    }
  }
}

resource "kubernetes_manifest" "keycloakrealm_keycloak_default" {
  depends_on = [kubernetes_manifest.keycloak_keycloak]
  manifest = {
    "apiVersion" = "keycloak.org/v1alpha1"
    "kind" = "KeycloakRealm"
    "metadata" = {
      "name" = "default"
      "namespace" = "keycloak"
      "labels" = {
        "realm" = "default"
      }
    }
    "spec" = {
      "instanceSelector" = {
        "matchLabels" = {
          "app" = "sso"
        }
      }
      "realm" = {
        "displayName" = "Baba Bourbaki"
        "displayNameHtml" = "<div class=\"kc-logo-text\"><span>Baba Bourbaki</span></div>"
        "enabled" = true
        "id" = "default"
        "realm" = "default"
        "clientScopes" = [
          {
            "name" = "microprofile-jwt"
            "description" = "Microprofile - JWT built-in scope"
            "protocol" = "openid-connect"
            "attributes" = {
              "include.in.token.scope" = "true"
              "display.on.consent.screen" = "false"
            }
            "protocolMappers" = [
              {
                "name" = "groups"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-realm-role-mapper"
                "consentRequired" = false
                "config" = {
                  "multivalued" = "true"
                  "user.attribute" = "foo"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "groups"
                  "jsonType.label" = "String"
                }
              }, {
                "name" = "upn"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-property-mapper"
                "consentRequired" = false
                "config" = {
                  "userinfo.token.claim" = "true"
                  "user.attribute" = "username"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "upn"
                  "jsonType.label" = "String"
                }
              }
            ]
          }, {
            "name" = "web-origins"
            "description" = "OpenID Connect scope for add allowed web origins to the access token"
            "protocol" = "openid-connect"
            "attributes" = {
              "include.in.token.scope" = "false"
              "display.on.consent.screen" = "false"
              "consent.screen.text" = ""
            }
            "protocolMappers" = [{
              "name" = "allowed web origins"
              "protocol" = "openid-connect"
              "protocolMapper" = "oidc-allowed-origins-mapper"
              "consentRequired" = false
            }]
          }, {
            "name" = "roles"
            "description" = "OpenID Connect scope for add user roles to the access token"
            "protocol" = "openid-connect"
            "attributes" = {
              "include.in.token.scope" = "false"
              "display.on.consent.screen" = "true"
              "consent.screen.text" = "$${rolesScopeConsentText}"
            }
            "protocolMappers" = [
              {
                "name" = "client roles"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-client-role-mapper"
                "consentRequired" = false
                "config" = {
                  "user.attribute" = "foo"
                  "access.token.claim" = "true"
                  "claim.name" = "resource_access.$${client_id}.roles"
                  "jsonType.label" = "String"
                  "multivalued" = "true"
                }
              }, {
                "name" = "realm roles"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-realm-role-mapper"
                "consentRequired" = false
                "config" = {
                  "user.attribute" = "foo"
                  "access.token.claim" = "true"
                  "claim.name" = "realm_access.roles"
                  "jsonType.label" = "String"
                  "multivalued" = "true"
                }
              }, {
                "name" = "audience resolve"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-audience-resolve-mapper"
                "consentRequired" = false
                "config" = {}
              }
            ]
          }, {
            "name" = "profile"
            "description" = "OpenID Connect built-in scope: profile"
            "protocol" = "openid-connect"
            "attributes" = {
              "include.in.token.scope" = "true"
              "display.on.consent.screen" = "true"
              "consent.screen.text" = "$${profileScopeConsentText}"
            }
            "protocolMappers" = [
              {
                "name" = "website"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-attribute-mapper"
                "consentRequired" = false
                "config" = {
                  "userinfo.token.claim" = "true"
                  "user.attribute" = "website"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "website"
                  "jsonType.label" = "String"
                }
              }, {
                "name" = "profile"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-attribute-mapper"
                "consentRequired" = false
                "config" = {
                  "userinfo.token.claim" = "true"
                  "user.attribute" = "profile"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "profile"
                  "jsonType.label" = "String"
                }
              }, {
                "name" = "username"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-property-mapper"
                "consentRequired" = false
                "config" = {
                  "userinfo.token.claim" = "true"
                  "user.attribute" = "username"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "preferred_username"
                  "jsonType.label" = "String"
                }
              }, {
                "name" = "full name"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-full-name-mapper"
                "consentRequired" = false
                "config" = {
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "userinfo.token.claim" = "true"
                }
              }, {
                "name" = "given name"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-property-mapper"
                "consentRequired" = false
                "config" = {
                  "userinfo.token.claim" = "true"
                  "user.attribute" = "firstName"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "given_name"
                  "jsonType.label" = "String"
                }
              }, {
                "name" = "picture"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-attribute-mapper"
                "consentRequired" = false
                "config" = {
                  "userinfo.token.claim" = "true"
                  "user.attribute" = "picture"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "picture"
                  "jsonType.label" = "String"
                }
              }, {
                "name" = "nickname"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-attribute-mapper"
                "consentRequired" = false
                "config" = {
                  "userinfo.token.claim" = "true"
                  "user.attribute" = "nickname"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "nickname"
                  "jsonType.label" = "String"
                }
              }, {
                "name" = "updated at"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-attribute-mapper"
                "consentRequired" = false
                "config" = {
                  "userinfo.token.claim" = "true"
                  "user.attribute" = "updatedAt"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "updated_at"
                  "jsonType.label" = "long"
                }
              }, {
                "name" = "locale"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-attribute-mapper"
                "consentRequired" = false
                "config" = {
                  "userinfo.token.claim" = "true"
                  "user.attribute" = "locale"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "locale"
                  "jsonType.label" = "String"
                }
              }, {
                "name" = "birthdate"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-attribute-mapper"
                "consentRequired" = false
                "config" = {
                  "userinfo.token.claim" = "true"
                  "user.attribute" = "birthdate"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "birthdate"
                  "jsonType.label" = "String"
                }
              }, {
                "name" = "family name"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-property-mapper"
                "consentRequired" = false
                "config" = {
                  "userinfo.token.claim" = "true"
                  "user.attribute" = "lastName"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "family_name"
                  "jsonType.label" = "String"
                }
              }, {
                "name" = "middle name"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-attribute-mapper"
                "consentRequired" = false
                "config" = {
                  "userinfo.token.claim" = "true"
                  "user.attribute" = "middleName"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "middle_name"
                  "jsonType.label" = "String"
                }
              }, {
                "name" = "gender"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-attribute-mapper"
                "consentRequired" = false
                "config" = {
                  "userinfo.token.claim" = "true"
                  "user.attribute" = "gender"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "gender"
                  "jsonType.label" = "String"
                }
              }, {
                "name" = "zoneinfo"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-attribute-mapper"
                "consentRequired" = false
                "config" = {
                  "userinfo.token.claim" = "true"
                  "user.attribute" = "zoneinfo"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "zoneinfo"
                  "jsonType.label" = "String"
                }
              }

        ]
          }, {
            "name" = "offline_access"
            "description" = "OpenID Connect built-in scope: offline_access"
            "protocol" = "openid-connect"
            "attributes" = {
              "consent.screen.text" = "$${offlineAccessScopeConsentText}"
              "display.on.consent.screen" = "true"
            }
          }, {
            "name" = "acr"
            "description" = "OpenID Connect scope for add acr (authentication context class reference) to the token"
            "protocol" = "openid-connect"
            "attributes" = {
              "include.in.token.scope" = "false"
              "display.on.consent.screen" = "false"
            }
            "protocolMappers" = [{
              "name" = "acr loa level"
              "protocol" = "openid-connect"
              "protocolMapper" = "oidc-acr-mapper"
              "consentRequired" = false
              "config" = {
                "id.token.claim" = "true"
                "access.token.claim" = "true"
              }
            }]
          }, {
            "name" = "email"
            "description" = "OpenID Connect built-in scope: email"
            "protocol" = "openid-connect"
            "attributes" = {
              "include.in.token.scope" = "true"
              "display.on.consent.screen" = "true"
              "consent.screen.text" = "$${emailScopeConsentText}"
            }
            "protocolMappers" = [
              {
                "name" = "email verified"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-property-mapper"
                "consentRequired" = false
                "config" = {
                  "userinfo.token.claim" = "true"
                  "user.attribute" = "emailVerified"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "email_verified"
                  "jsonType.label" = "boolean"
                }
              }, {
                "name" = "email"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-property-mapper"
                "consentRequired" = false
                "config" = {
                  "userinfo.token.claim" = "true"
                  "user.attribute" = "email"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "email"
                  "jsonType.label" = "String"
                }
              }
            ]
          }, {
            "name" = "address"
            "description" = "OpenID Connect built-in scope: address"
            "protocol" = "openid-connect"
            "attributes" = {
              "include.in.token.scope" = "true"
              "display.on.consent.screen" = "true"
              "consent.screen.text" = "$${addressScopeConsentText}"
            }
            "protocolMappers" = [{
              "name" = "address"
              "protocol" = "openid-connect"
              "protocolMapper" = "oidc-address-mapper"
              "consentRequired" = false
              "config" = {
                "user.attribute.formatted" = "formatted"
                "user.attribute.country" = "country"
                "user.attribute.postal_code" = "postal_code"
                "userinfo.token.claim" = "true"
                "user.attribute.street" = "street"
                "id.token.claim" = "true"
                "user.attribute.region" = "region"
                "access.token.claim" = "true"
                "user.attribute.locality" = "locality"
              }
            }]
          }, {
            "name" = "role_list"
            "description" = "SAML role list"
            "protocol" = "saml"
            "attributes" = {
              "consent.screen.text" = "$${samlRoleListScopeConsentText}"
              "display.on.consent.screen" = "true"
            }
            "protocolMappers" = [
              {
                "name" = "role list"
                "protocol" = "saml"
                "protocolMapper" = "saml-role-list-mapper"
                "consentRequired" = false
                "config" = {
                  "single" = "false"
                  "attribute.nameformat" = "Basic"
                  "attribute.name" = "Role"
                }
              }
            ]
          }, {
            "name" = "phone"
            "description" = "OpenID Connect built-in scope: phone"
            "protocol" = "openid-connect"
            "attributes" = {
              "include.in.token.scope" = "true"
              "display.on.consent.screen" = "true"
              "consent.screen.text" = "$${phoneScopeConsentText}"
            }
            "protocolMappers" = [
              {
                "name" = "phone number"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-attribute-mapper"
                "consentRequired" = false
                "config" = {
                  "userinfo.token.claim" = "true"
                  "user.attribute" = "phoneNumber"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "phone_number"
                  "jsonType.label" = "String"
                }
              }, {
                "name" = "phone number verified"
                "protocol" = "openid-connect"
                "protocolMapper" = "oidc-usermodel-attribute-mapper"
                "consentRequired" = false
                "config" = {
                  "userinfo.token.claim" = "true"
                  "user.attribute" = "phoneNumberVerified"
                  "id.token.claim" = "true"
                  "access.token.claim" = "true"
                  "claim.name" = "phone_number_verified"
                  "jsonType.label" = "boolean"
                }
              }
            ]
          },
        ]
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
          "realm" = "default"
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
          "realm" = "default"
        }
      }
    }
  }
}
