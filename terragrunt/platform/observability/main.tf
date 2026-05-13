locals {
  argocd_namespace = "argocd"
  namespace        = "observability"

  grafana_hostname     = "${var.subdomain}.${var.domain}"
  grafana_url          = "https://${local.grafana_hostname}"
  grafana_redirect_uri = "${local.grafana_url}/login/generic_oauth"

  oidc_application_slug = "grafana"
  oidc_client_id        = "grafana"

  oidc_secret_name     = "grafana-oidc"
  oidc_secret_checksum = sha256(random_password.grafana_oidc_client_secret.result)
}

resource "terraform_data" "argocd_gate" {
  input = var.argocd_ready
}

resource "terraform_data" "platform_data_gate" {
  input = var.platform_data_ready
}

resource "terraform_data" "authentik_gate" {
  input = var.authentik_ready
}

# Hosts Prometheus, Alertmanager, Grafana, kube-state-metrics. node-exporter
# is a DaemonSet that lands in this namespace but uses hostNetwork — that's
# why this namespace runs at the `privileged` PSA level. Scoped tightly here;
# no other workload lives in `observability`.
resource "kubernetes_namespace" "observability" {
  metadata {
    name = local.namespace
    labels = {
      "managed-by"                         = "terragrunt"
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

# ---------------------------------------------------------------------------
# Authentik OIDC client for Grafana. Same shape as services/argocd-oidc/ —
# data lookups for default flows + property mappings, oauth2 provider with
# a generated client_secret, application bound to it. Plus a dedicated
# `groups` property mapping (authentik's defaults don't include one, and the
# existing argocd-groups mapping is owned by services/, can't reach across
# layers).
# ---------------------------------------------------------------------------

data "authentik_flow" "default_authorization" {
  slug       = "default-provider-authorization-implicit-consent"
  depends_on = [terraform_data.authentik_gate]
}

data "authentik_flow" "default_authentication" {
  slug       = "default-authentication-flow"
  depends_on = [terraform_data.authentik_gate]
}

data "authentik_flow" "default_invalidation" {
  slug       = "default-provider-invalidation-flow"
  depends_on = [terraform_data.authentik_gate]
}

data "authentik_certificate_key_pair" "default" {
  name       = "authentik Self-signed Certificate"
  depends_on = [terraform_data.authentik_gate]
}

data "authentik_property_mapping_provider_scope" "openid" {
  name       = "authentik default OAuth Mapping: OpenID 'openid'"
  depends_on = [terraform_data.authentik_gate]
}

data "authentik_property_mapping_provider_scope" "profile" {
  name       = "authentik default OAuth Mapping: OpenID 'profile'"
  depends_on = [terraform_data.authentik_gate]
}

data "authentik_property_mapping_provider_scope" "email" {
  name       = "authentik default OAuth Mapping: OpenID 'email'"
  depends_on = [terraform_data.authentik_gate]
}

resource "authentik_property_mapping_provider_scope" "groups" {
  name       = "grafana-groups"
  scope_name = "groups"
  expression = "return {\"groups\": [group.name for group in user.ak_groups.all()]}"

  depends_on = [terraform_data.authentik_gate]
}

resource "random_password" "grafana_oidc_client_secret" {
  length  = 48
  special = false
}

resource "authentik_provider_oauth2" "grafana" {
  name          = "grafana"
  client_id     = local.oidc_client_id
  client_secret = random_password.grafana_oidc_client_secret.result

  authorization_flow  = data.authentik_flow.default_authorization.id
  authentication_flow = data.authentik_flow.default_authentication.id
  invalidation_flow   = data.authentik_flow.default_invalidation.id

  signing_key = data.authentik_certificate_key_pair.default.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = local.grafana_redirect_uri
    },
  ]

  property_mappings = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.profile.id,
    data.authentik_property_mapping_provider_scope.email.id,
    authentik_property_mapping_provider_scope.groups.id,
  ]

  sub_mode = "hashed_user_id"
}

resource "authentik_application" "grafana" {
  name              = "Grafana"
  slug              = local.oidc_application_slug
  protocol_provider = authentik_provider_oauth2.grafana.id
  meta_launch_url   = local.grafana_url
}

# Grafana reads OIDC client credentials from env vars. The chart's
# `envFromSecret` mounts every key in this Secret as an env var, and
# grafana.ini fields written as `$__env{NAME}` interpolate from those.
resource "kubernetes_secret" "grafana_oidc" {
  metadata {
    name      = local.oidc_secret_name
    namespace = kubernetes_namespace.observability.metadata[0].name
  }

  data = {
    GF_AUTH_GENERIC_OAUTH_CLIENT_ID     = local.oidc_client_id
    GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET = random_password.grafana_oidc_client_secret.result
  }
}

# ---------------------------------------------------------------------------
# kube-prometheus-stack via Argo CD. Bundles Prometheus operator, Prometheus,
# Alertmanager, Grafana, node-exporter, kube-state-metrics, and the CRDs.
# ---------------------------------------------------------------------------

resource "kubectl_manifest" "argo_app_kube_prometheus_stack" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "kube-prometheus-stack"
      namespace = local.argocd_namespace
    }
    spec = {
      project = "platform"
      source = {
        repoURL        = "https://prometheus-community.github.io/helm-charts"
        chart          = "kube-prometheus-stack"
        targetRevision = var.kube_prometheus_stack_chart_version
        helm = {
          # Short release name so Prometheus-operator-generated PVC names
          # stay under Hetzner Cloud's 64-char label-value limit. The default
          # release name (`kube-prometheus-stack`) produces ~90-char PVC
          # names that hcloud-csi can't propagate as labels.
          releaseName = "monitoring"
          values      = var.kube_prometheus_stack_values
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.observability.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        # ServerSideApply needed for the chart's CRDs — they exceed the
        # 256 KiB client-side annotation limit, same as CNPG.
        syncOptions = [
          "ServerSideApply=true",
          "CreateNamespace=false",
        ]
      }
    }
  })

  depends_on = [
    terraform_data.argocd_gate,
    terraform_data.platform_data_gate,
    kubernetes_namespace.observability,
    kubernetes_secret.grafana_oidc,
    authentik_application.grafana,
  ]
}

# ---------------------------------------------------------------------------
# HTTPRoute for Grafana. Direct backend — Grafana speaks OIDC to Authentik
# natively, no oauth2-proxy in front. Prometheus and Alertmanager stay
# cluster-internal (port-forward when you need them).
# ---------------------------------------------------------------------------

resource "terraform_data" "wait_for_grafana_svc" {
  triggers_replace = {
    namespace = kubernetes_namespace.observability.metadata[0].name
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      set -euo pipefail
      ns="${kubernetes_namespace.observability.metadata[0].name}"
      for i in $(seq 1 60); do
        if kubectl -n "$ns" get svc monitoring-grafana >/dev/null 2>&1; then
          echo "$ns/monitoring-grafana ready"
          exit 0
        fi
        echo "waiting for $ns/monitoring-grafana (attempt $i/60)..."
        sleep 5
      done
      echo "$ns/monitoring-grafana never appeared after 5 minutes" >&2
      exit 1
    EOT
  }

  depends_on = [kubectl_manifest.argo_app_kube_prometheus_stack]
}

resource "kubectl_manifest" "httproute_grafana" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "grafana"
      namespace = kubernetes_namespace.observability.metadata[0].name
    }
    spec = {
      parentRefs = [
        {
          group       = "gateway.networking.k8s.io"
          kind        = "Gateway"
          name        = var.gateway_name
          namespace   = var.gateway_namespace
          sectionName = "https"
        }
      ]
      hostnames = [local.grafana_hostname]
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
              name = "monitoring-grafana"
              port = 80
            }
          ]
        }
      ]
    }
  })

  depends_on = [terraform_data.wait_for_grafana_svc]
}

resource "terraform_data" "observability_ready" {
  triggers_replace = [
    kubectl_manifest.argo_app_kube_prometheus_stack.uid,
    kubectl_manifest.httproute_grafana.uid,
  ]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      set -euo pipefail
      kubectl wait --for=jsonpath='{.status.sync.status}'=Synced \
        application/kube-prometheus-stack -n ${local.argocd_namespace} --timeout=15m
      kubectl wait --for=jsonpath='{.status.health.status}'=Healthy \
        application/kube-prometheus-stack -n ${local.argocd_namespace} --timeout=10m
      kubectl -n ${kubernetes_namespace.observability.metadata[0].name} \
        wait --for=jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'=True \
        httproute/grafana --timeout=5m
    EOT
  }
}
