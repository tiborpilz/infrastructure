variable "domain" {
  type        = string
  description = "The domain to use"
}

variable "keycloak_version" {
  type        = string
  description = "The keycloak version to use"
  default     = "master"
}

variable "default_username" {
  type        = string
  description = "The default username to use"
  default     = "admin"
}

variable "default_password" {
  type        = string
  description = "The default password to use"
  default     = "admin"
}

module "keycloak_operator" {
  source = "../download-manifest"
  urls = [
    "https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/${var.keycloak_version}/kubernetes/keycloaks.k8s.keycloak.org-v1.yml",
    "https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/${var.keycloak_version}/kubernetes/keycloakrealmimports.k8s.keycloak.org-v1.yml",
    "https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/${var.keycloak_version}/kubernetes/kubernetes.yml"
  ]
  namespace   = "keycloak"
  output_file = "${path.module}/templates-out/keycloak-operator.yaml"
}

module "keycloak_realm_operator" {
  source = "../download-manifest"
  urls = [
    "https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/crds/legacy.k8s.keycloak.org_externalkeycloaks_crd.yaml",
    "https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/crds/legacy.k8s.keycloak.org_keycloakclients_crd.yaml",
    "https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/crds/legacy.k8s.keycloak.org_keycloakrealms_crd.yaml",
    "https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/crds/legacy.k8s.keycloak.org_keycloakusers_crd.yaml",
    "https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/role.yaml",
    "https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/role_binding.yaml",
    "https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/service_account.yaml",
    "https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/operator.yaml",
  ]
  namespace   = "keycloak"
  output_file = "${path.module}/templates-out/keycloak-realm-operator.yaml"
}

locals {
  namespace_manifest = templatefile("${path.module}/templates/namespace.tpl.yaml", {
    name = "keycloak"
  })

  keycloak_manifest = templatefile("${path.module}/templates/keycloak.tpl.yaml", {
    domain   = var.domain
    username = var.default_username
    password = var.default_password
  })
}

resource "local_file" "namespace" {
  filename = "${path.module}/templates-out/namespace.yaml"
  content  = local.namespace_manifest
}

resource "local_file" "keycloak" {
  filename = "${path.module}/templates-out/keycloak.yaml"
  content  = local.keycloak_manifest
}

output "files" {
  value = [
    # Namespace
    local_file.namespace.filename,

    # Keycloak Operator
    module.keycloak_operator.file.filename,

    # Realm Operator
    module.keycloak_realm_operator.file.filename,

    # Keycloak instance
    local_file.keycloak.filename,
  ]
}

output "manifest" {
  value = join("\n---\n", [
    local.namespace_manifest,
    module.keycloak_operator.manifest,
    module.keycloak_realm_operator.manifest,
    local.keycloak_manifest
  ])
}
