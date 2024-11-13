/**
 * # Cluster
 *
 * This module creates a kubernetes cluster using rke.
 * It also installs argocd, keycloak, cert-manager, ingress-nginx and metallb.
 */

terraform {
  required_providers {
    rke = {
      source  = "rancher/rke"
      version = "1.6.0"
    }
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "17.5.0"
    }
  }
}

provider "gitlab" {
  token = var.gitlab_token
}

module "metallb" {
  source          = "../metallb"
  ips             = var.ingress_ips
  metallb_version = var.versions.metallb
}

module "hcloud_csi" {
  source       = "../hcloud-csi"
  hcloud_token = var.hcloud_token
}

module "keycloak" {
  source           = "../keycloak"
  keycloak_version = var.versions.keycloak
  domain           = var.domain
  default_password = var.keycloak_admin_password
}

module "cert_manager" {
  source               = "../cert-manager"
  cert_manager_version = var.versions.cert_manager
  email                = var.email
}

module "ingress_nginx" {
  source                = "../ingress-nginx"
  ingress_nginx_version = var.versions.ingress_nginx
}

data "gitlab_project" "infrastructure" {
  id = var.gitlab_infrastructure_project_id
}

# TODO: Move to own module
resource "gitlab_project_access_token" "registry_rke" {
  project    = data.gitlab_project.infrastructure.id
  name       = "rke"
  scopes     = ["read_registry", "write_registry"]
  expires_at = "2024-12-01"
}

resource "rke_cluster" "cluster" {
  dynamic "nodes" {
    for_each = var.nodes
    content {
      address = nodes.value.ipv4_address
      user    = "root"
      role = [for role in [
        nodes.value.labels["etcd"] == "true" ? "etcd" : null,
        nodes.value.labels["controlplane"] == "true" ? "controlplane" : null,
        nodes.value.labels["worker"] == "true" ? "worker" : null,
      ] : role if role != null]
      ssh_key = var.ssh_key.private_key_pem
    }
  }
  kubernetes_version = var.versions.rke_kubernetes
  network {
    plugin = "canal"
  }
  ingress {
    provider = "none"
    # These values are not used, but if they're missing terraform will try to re-create the cluster on every apply
    http_port    = 80
    https_port   = 443
    network_mode = "hostPort"
  }
  addons_include = concat(
    module.ingress_nginx.files,
    module.cert_manager.files,
    module.metallb.files,
    module.hcloud_csi.files,
    module.keycloak.files,
  )
  services {
    kube_api {
      extra_args = {
        "oidc-issuer-url" = "https://keycloak.${var.domain}/realms/default"
        "oidc-client-id"  = "kubernetes"
      }
    }
  }
  upgrade_strategy {
    drain                        = true
    max_unavailable_worker       = "100%"
    max_unavailable_controlplane = "100%"
    drain_input {
      delete_local_data  = false
      force              = true
      ignore_daemon_sets = true
      timeout            = 120
    }
  }
  enable_cri_dockerd    = true
  ignore_docker_version = true

  # TODO: something with for_each
  private_registries {
     url = "harbor.tbr.gg"
     password = "FGuBMgYQHWbJtFLOIu1uwD3LfYEPEpDR"
     user = "robot$kubernetes"
  }

  # TODO: something with for_each
  private_registries {
    url = "gitlab.com"
    password = gitlab_project_access_token.registry_rke.token
    user = data.gitlab_project.infrastructure.name
  }

  # Keycloak needs to be up before we can move on.
  provisioner "local-exec" {
    command    = "while true; do curl -k 'https://keycloak.${var.domain}' && break || sleep 3; done"
    on_failure = continue
  }
}

resource "local_file" "kube_cluster_yaml" {
  filename = "${path.root}/../out/kube_config_cluster.yml"
  content  = rke_cluster.cluster.kube_config_yaml
}

resource "local_file" "rke_cluster_yaml" {
  filename = "${path.root}/../out/rke_cluster.yml"
  content  = rke_cluster.cluster.rke_cluster_yaml
}

output "cluster_connection" {
  sensitive = true
  value = {
    host                   = rke_cluster.cluster.api_server_url
    cluster_ca_certificate = rke_cluster.cluster.ca_crt
    client_certificate     = rke_cluster.cluster.client_cert
    client_key             = rke_cluster.cluster.client_key
  }
}

output "kube_config_yaml" {
  sensitive = true
  value = rke_cluster.cluster.kube_config_yaml
}
