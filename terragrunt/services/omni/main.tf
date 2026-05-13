locals {
  # Whole module is dormant until a GPG etcd encryption key is supplied via
  # SOPS. We gate each create-resource on this rather than the module call
  # because providers.tf forbids count/for_each on the calling module.
  enabled = var.omni_etcd_gpg_key != ""

  argocd_namespace = "argocd"
  namespace        = "omni"

  omni_hostname       = "${var.subdomain}.${var.domain}"
  k8s_proxy_hostname  = "${var.k8s_proxy_subdomain}.${var.domain}"
  siderolink_hostname = "${var.siderolink_subdomain}.${var.domain}"

  omni_url       = "https://${local.omni_hostname}"
  k8s_proxy_url  = "https://${local.k8s_proxy_hostname}"
  siderolink_url = "https://${local.siderolink_hostname}"

  oidc_application_slug = "omni"
  oidc_client_id        = "omni"
  # Omni's OIDC handler registers the consume route at /oidc/consume
  # (internal/backend/oidc/handlers.go:RedirectURL).
  oidc_redirect_uri = "${local.omni_url}/oidc/consume"
  oidc_logout_url   = "${var.authentik_url}/application/o/${local.oidc_application_slug}/end-session/"
  oidc_provider_url = "${var.authentik_url}/application/o/${local.oidc_application_slug}/"

  oidc_client_secret = try(random_password.omni_oidc_client_secret[0].result, "")

  etcd_key_secret_name = "omni-etcd-gpg"
  oidc_secret_name     = "omni-oidc-config"

  oidc_secret_checksum = sha256(local.oidc_client_secret)
  etcd_key_checksum    = sha256(var.omni_etcd_gpg_key)

  base_values = yamldecode(var.omni_values_yaml)

  account_id = try(random_uuid.account_id[0].result, "")

  # additionalConfigSources loads the OIDC clientSecret from a Secret so it
  # never appears in the ArgoCD Application spec or chart values as plaintext.
  patched_config = merge(local.base_values.config, {
    account = merge(try(local.base_values.config.account, {}), {
      id = local.account_id
    })
    auth = merge(local.base_values.config.auth, {
      oidc = merge(local.base_values.config.auth.oidc, {
        clientID    = local.oidc_client_id
        providerURL = local.oidc_provider_url
        logoutURL   = local.oidc_logout_url
      })
      initialUsers = var.omni_admin_emails
    })
    services = merge(local.base_values.config.services, {
      siderolink = merge(local.base_values.config.services.siderolink, {
        wireGuard = merge(local.base_values.config.services.siderolink.wireGuard, {
          advertisedEndpoint = var.siderolink_wireguard_endpoint
        })
      })
    })
  })

  helm_values = yamlencode(merge(local.base_values, {
    config = local.patched_config
    additionalConfigSources = [
      {
        existingSecret = local.oidc_secret_name
        key            = "config.yaml"
      },
    ]
    etcdEncryptionKey = {
      existingSecret = local.etcd_key_secret_name
    }
    podAnnotations = merge(try(local.base_values.podAnnotations, {}), {
      "checksum/omni-oidc"     = local.oidc_secret_checksum
      "checksum/omni-etcd-key" = local.etcd_key_checksum
    })
  }))
}

resource "terraform_data" "platform_data_gate" {
  input = var.platform_data_ready
}

resource "terraform_data" "authentik_gate" {
  input = var.authentik_ready
}

resource "terraform_data" "authentik_config_gate" {
  input = var.authentik_config_ready
}

resource "kubernetes_namespace" "omni" {
  count = local.enabled ? 1 : 0

  metadata {
    name = local.namespace
    labels = {
      "managed-by" = "terragrunt"

      # Omni's pod needs NET_ADMIN (to set up the WireGuard interface) and a
      # /dev/net/tun hostPath. Both violate the cluster-default PodSecurity
      # `baseline` policy, so this namespace runs at `privileged`. Scope is
      # the omni namespace only — no impact on other workloads.
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

# Stable across applies; storing it in TF state means the account_id never
# rotates unless the user explicitly taints it. Changing it would orphan all
# clusters Omni has linked.
resource "random_uuid" "account_id" {
  count = local.enabled ? 1 : 0
}

resource "random_password" "omni_oidc_client_secret" {
  count = local.enabled ? 1 : 0

  length  = 48
  special = false
}

# Omni's `etcdEncryptionKey.existingSecret` expects a Secret with the GPG key
# at key `omni.asc` (chart mounts it at `/omni.asc`).
resource "kubernetes_secret" "omni_etcd_gpg" {
  count = local.enabled ? 1 : 0

  metadata {
    name      = local.etcd_key_secret_name
    namespace = kubernetes_namespace.omni[0].metadata[0].name
  }

  data = {
    "omni.asc" = var.omni_etcd_gpg_key
  }
}

# Omni's `additionalConfigSources` loads a partial Omni config YAML from this
# Secret and merges it into the chart-rendered config. We use it to inject the
# OIDC clientSecret without leaking it through the ArgoCD Application spec.
resource "kubernetes_secret" "omni_oidc_config" {
  count = local.enabled ? 1 : 0

  metadata {
    name      = local.oidc_secret_name
    namespace = kubernetes_namespace.omni[0].metadata[0].name
  }

  data = {
    "config.yaml" = yamlencode({
      auth = {
        oidc = {
          clientSecret = local.oidc_client_secret
        }
      }
    })
  }
}

data "authentik_flow" "default_authorization" {
  count = local.enabled ? 1 : 0
  slug  = "default-provider-authorization-implicit-consent"

  depends_on = [terraform_data.authentik_gate]
}

data "authentik_flow" "default_authentication" {
  count = local.enabled ? 1 : 0
  slug  = "default-authentication-flow"

  depends_on = [terraform_data.authentik_gate]
}

data "authentik_flow" "default_invalidation" {
  count = local.enabled ? 1 : 0
  slug  = "default-provider-invalidation-flow"

  depends_on = [terraform_data.authentik_gate]
}

data "authentik_certificate_key_pair" "default" {
  count = local.enabled ? 1 : 0
  name  = "authentik Self-signed Certificate"

  depends_on = [terraform_data.authentik_gate]
}

data "authentik_property_mapping_provider_scope" "openid" {
  count = local.enabled ? 1 : 0
  name  = "authentik default OAuth Mapping: OpenID 'openid'"

  depends_on = [terraform_data.authentik_gate]
}

data "authentik_property_mapping_provider_scope" "profile" {
  count = local.enabled ? 1 : 0
  name  = "authentik default OAuth Mapping: OpenID 'profile'"

  depends_on = [terraform_data.authentik_gate]
}

data "authentik_property_mapping_provider_scope" "email" {
  count = local.enabled ? 1 : 0
  name  = "authentik default OAuth Mapping: OpenID 'email'"

  depends_on = [terraform_data.authentik_gate]
}

resource "authentik_provider_oauth2" "omni" {
  count = local.enabled ? 1 : 0

  name          = "omni"
  client_id     = local.oidc_client_id
  client_secret = local.oidc_client_secret

  authorization_flow  = data.authentik_flow.default_authorization[0].id
  authentication_flow = data.authentik_flow.default_authentication[0].id
  invalidation_flow   = data.authentik_flow.default_invalidation[0].id

  signing_key = data.authentik_certificate_key_pair.default[0].id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = local.oidc_redirect_uri
    },
  ]

  property_mappings = [
    data.authentik_property_mapping_provider_scope.openid[0].id,
    data.authentik_property_mapping_provider_scope.profile[0].id,
    data.authentik_property_mapping_provider_scope.email[0].id,
  ]

  sub_mode = "hashed_user_id"
}

resource "authentik_application" "omni" {
  count = local.enabled ? 1 : 0

  name              = "Omni"
  slug              = local.oidc_application_slug
  protocol_provider = authentik_provider_oauth2.omni[0].id
  meta_launch_url   = local.omni_url
}

resource "kubectl_manifest" "argo_app_omni" {
  count = local.enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "omni"
      namespace = local.argocd_namespace
    }
    spec = {
      project = "platform"
      source = {
        repoURL        = "https://github.com/siderolabs/omni"
        path           = "deploy/helm/omni"
        targetRevision = var.omni_chart_revision
        helm = {
          releaseName = "omni"
          values      = local.helm_values
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.omni[0].metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "ServerSideApply=true",
          "CreateNamespace=false",
        ]
      }
    }
  })

  depends_on = [
    terraform_data.platform_data_gate,
    terraform_data.authentik_gate,
    terraform_data.authentik_config_gate,
    authentik_application.omni,
    kubernetes_secret.omni_etcd_gpg,
    kubernetes_secret.omni_oidc_config,
  ]
}
#
# resource "terraform_data" "omni_ready" {
#   count = local.enabled ? 1 : 0
#
#   triggers_replace = [
#     kubectl_manifest.argo_app_omni[0].uid,
#   ]
#
#   provisioner "local-exec" {
#     environment = {
#       KUBECONFIG = var.kubeconfig_path
#     }
#     command = <<-EOT
#       set -euo pipefail
#       kubectl wait --for=jsonpath='{.status.sync.status}'=Synced \
#         application/omni -n ${local.argocd_namespace} --timeout=10m
#       kubectl -n ${kubernetes_namespace.omni[0].metadata[0].name} \
#         rollout status deployment/omni --timeout=10m
#       kubectl -n ${kubernetes_namespace.omni[0].metadata[0].name} \
#         wait --for=jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'=True \
#         httproute/omni-ui --timeout=5m
#       kubectl wait --for=jsonpath='{.status.health.status}'=Healthy \
#         application/omni -n ${local.argocd_namespace} --timeout=5m
#     EOT
#   }
# }
