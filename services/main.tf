variable "cluster_connection" {
  type = map(any)
  default = {}
}
variable domain {
  type = string
  default = ""
}
variable kube_config_yaml {
  type = string
  default = ""
}

terraform {
  required_providers {
    kustomization = {
      source = "kbst/kustomization"
    }
  }
  backend "local" {}
}

provider "kustomization" {
  kubeconfig_raw = var.kube_config_yaml
}

provider "kubernetes" {
  experiments {
    manifest_resource = true
  }

  host     = var.cluster_connection.api_server_url
  username = var.cluster_connection.kube_admin_user

  client_certificate     = var.cluster_connection.client_cert
  client_key             = var.cluster_connection.client_key
  cluster_ca_certificate = var.cluster_connection.ca_crt
}

data "kustomization_build" "keycloak" {
  path = "../applications/manifests/keycloak"
}

resource "kustomization_resource" "keycloak" {
  for_each = data.kustomization_build.keycloak.ids
  manifest = data.kustomization_build.keycloak.manifests[each.value]
}
