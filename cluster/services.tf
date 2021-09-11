data "kustomization_build" "keycloak" {
  path = "../applications/manifests/keycloak"
}

resource "kustomization_resource" "keycloak" {
  for_each = data.kustomization_build.keycloak.ids
  manifest = data.kustomization_build.keycloak.manifests[each.value]
}
