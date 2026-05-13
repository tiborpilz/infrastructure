locals {
  hostname  = "${var.subdomain}.${var.domain}"
  app_name  = "smoke"
  app_label = { app = local.app_name }
}

resource "kubernetes_namespace" "smoke" {
  metadata {
    name = local.app_name
    labels = {
      "managed-by" = "terragrunt"
    }
  }
}

resource "kubernetes_deployment_v1" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.smoke.metadata[0].name
    labels    = local.app_label
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.app_label
    }

    template {
      metadata {
        labels = local.app_label
      }
      spec {
        container {
          name  = "nginx"
          image = var.image

          port {
            container_port = 80
            name           = "http"
          }

          readiness_probe {
            http_get {
              path = "/"
              port = "http"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.smoke.metadata[0].name
    labels    = local.app_label
  }

  spec {
    type     = "ClusterIP"
    selector = local.app_label

    port {
      name        = "http"
      port        = 80
      target_port = "http"
    }
  }
}

# HTTPRoute attaches to the public Gateway in gateway-system.
# external-dns will see the hostname and create the Cloudflare A record.
# The Gateway's wildcard TLS cert covers <hostname>.
resource "kubectl_manifest" "httproute" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = local.app_name
      namespace = kubernetes_namespace.smoke.metadata[0].name
    }
    spec = {
      parentRefs = [
        {
          name        = var.gateway_name
          namespace   = var.gateway_namespace
          sectionName = "https"
        }
      ]
      hostnames = [local.hostname]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          backendRefs = [
            {
              name = kubernetes_service_v1.nginx.metadata[0].name
              port = 80
            }
          ]
        }
      ]
    }
  })
}
