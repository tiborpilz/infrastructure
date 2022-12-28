data "kubernetes_resource" "keycloak_user_tibor" {
    api_version = "keycloak.org/v1alpha1"
    kind = "KeycloakUser"

    metadata {
        name      = "tibor"
        namespace = "keycloak"
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
        name      = "https://keycloak.${var.domain}/auth/realms/master#${data.kubernetes_resource.keycloak_user_tibor.object.spec.user.id}"
        api_group = "rbac.authorization.k8s.io"
    }
}

output "keycloak_user_tibor" {
    value = data.kubernetes_resource.keycloak_user_tibor.object.spec.user.id
}
