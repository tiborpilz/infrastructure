locals {
  argocd_namespace = "argocd"
  namespace        = "woodpecker"
  hostname         = "${var.subdomain}.${var.domain}"
  woodpecker_url   = "https://${local.hostname}"

  forgejo_oauth_name         = "woodpecker"
  forgejo_oauth_redirect_uri = "${local.woodpecker_url}/authorize"

  agent_secret_checksum = sha256(random_password.agent_secret.result)

  bootstrap_input_secret  = "woodpecker-bootstrap-input"
  bootstrap_output_secret = "woodpecker-oauth"
  bootstrap_job_name      = "woodpecker-oauth-bootstrap"
  bootstrap_image         = "alpine/k8s:1.30.4"

  base_values = yamldecode(var.woodpecker_values_yaml)

  envfrom_secret_names = distinct(concat(
    try(local.base_values.server.extraSecretNamesForEnvFrom, []),
    [local.bootstrap_output_secret],
  ))

  patched_server = merge(local.base_values.server, {
    extraSecretNamesForEnvFrom = local.envfrom_secret_names
    podAnnotations = merge(try(local.base_values.server.podAnnotations, {}), {
      "checksum/woodpecker-secret" = local.agent_secret_checksum
    })
  })

  patched_agent = merge(local.base_values.agent, {
    extraSecretNamesForEnvFrom = local.envfrom_secret_names
    podAnnotations = merge(try(local.base_values.agent.podAnnotations, {}), {
      "checksum/woodpecker-secret" = local.agent_secret_checksum
    })
  })

  helm_values = yamlencode(merge(local.base_values, {
    server = local.patched_server
    agent  = local.patched_agent
  }))
}

resource "terraform_data" "platform_data_gate" {
  input = var.platform_data_ready
}

resource "terraform_data" "forgejo_gate" {
  input = var.forgejo_ready
}

resource "kubernetes_namespace" "woodpecker" {
  metadata {
    name = local.namespace
    labels = {
      "managed-by" = "terragrunt"
    }
  }
}

data "kubernetes_secret" "forgejo_admin" {
  metadata {
    name      = "forgejo-admin"
    namespace = var.forgejo_namespace
  }

  depends_on = [terraform_data.forgejo_gate]
}

resource "random_password" "agent_secret" {
  length  = 64
  special = false
}

resource "kubernetes_secret" "woodpecker" {
  metadata {
    name      = "woodpecker-secrets"
    namespace = kubernetes_namespace.woodpecker.metadata[0].name
  }

  data = {
    WOODPECKER_AGENT_SECRET = random_password.agent_secret.result
  }
}

resource "kubernetes_secret" "bootstrap_input" {
  metadata {
    name      = local.bootstrap_input_secret
    namespace = kubernetes_namespace.woodpecker.metadata[0].name
  }

  data = {
    FORGEJO_ADMIN_USERNAME = data.kubernetes_secret.forgejo_admin.data["username"]
    FORGEJO_ADMIN_PASSWORD = data.kubernetes_secret.forgejo_admin.data["password"]
  }
}

resource "kubernetes_service_account" "bootstrap" {
  metadata {
    name      = "woodpecker-oauth-bootstrap"
    namespace = kubernetes_namespace.woodpecker.metadata[0].name
  }
}

resource "kubernetes_role" "bootstrap" {
  metadata {
    name      = "woodpecker-oauth-bootstrap"
    namespace = kubernetes_namespace.woodpecker.metadata[0].name
  }

  # RBAC's resourceNames doesn't match on create (no name yet) or
  # list/watch (collection-level), so these verbs are namespace-wide.
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create", "list", "watch"]
  }

  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = [local.bootstrap_output_secret]
    verbs          = ["get", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding" "bootstrap" {
  metadata {
    name      = "woodpecker-oauth-bootstrap"
    namespace = kubernetes_namespace.woodpecker.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.bootstrap.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.bootstrap.metadata[0].name
    namespace = kubernetes_namespace.woodpecker.metadata[0].name
  }
}

resource "kubectl_manifest" "bootstrap_job" {
  yaml_body = yamlencode({
    apiVersion = "batch/v1"
    kind       = "Job"
    metadata = {
      name      = local.bootstrap_job_name
      namespace = kubernetes_namespace.woodpecker.metadata[0].name
      labels = {
        "managed-by" = "terragrunt"
      }
    }
    spec = {
      backoffLimit            = 5
      ttlSecondsAfterFinished = 600
      template = {
        spec = {
          restartPolicy      = "OnFailure"
          serviceAccountName = kubernetes_service_account.bootstrap.metadata[0].name
          containers = [{
            name  = "bootstrap"
            image = local.bootstrap_image
            envFrom = [{
              secretRef = { name = kubernetes_secret.bootstrap_input.metadata[0].name }
            }]
            env = [
              { name = "NS", value = kubernetes_namespace.woodpecker.metadata[0].name },
              { name = "SECRET_NAME", value = local.bootstrap_output_secret },
              { name = "APP_NAME", value = local.forgejo_oauth_name },
              { name = "FORGEJO_URL", value = var.forgejo_url },
              { name = "REDIRECT_URI", value = local.forgejo_oauth_redirect_uri },
            ]
            command = ["/bin/sh", "-eu", "-c"]
            args = [<<-EOT
              existing=$(kubectl -n "$NS" get secret "$SECRET_NAME" -o json 2>/dev/null || true)
              if [ -n "$existing" ]; then
                client=$(printf '%s' "$existing" | jq -r '.data.WOODPECKER_FORGEJO_CLIENT // empty' | (base64 -d 2>/dev/null || true))
                secret=$(printf '%s' "$existing" | jq -r '.data.WOODPECKER_FORGEJO_SECRET // empty' | (base64 -d 2>/dev/null || true))
                if [ -n "$client" ] && [ -n "$secret" ]; then
                  echo "$SECRET_NAME already populated; nothing to do."
                  exit 0
                fi
              fi

              AUTH="$FORGEJO_ADMIN_USERNAME:$FORGEJO_ADMIN_PASSWORD"
              API="$FORGEJO_URL/api/v1/user/applications/oauth2"

              fetch() {
                METHOD="$1"; URL="$2"; BODY="$${3:-}"
                if [ -n "$BODY" ]; then
                  curl -s -u "$AUTH" -X "$METHOD" -H 'Content-Type: application/json' \
                    -w '\n%%{http_code}' -d "$BODY" "$URL"
                else
                  curl -s -u "$AUTH" -X "$METHOD" -w '\n%%{http_code}' "$URL"
                fi
              }

              RAW=$(fetch GET "$API")
              HTTP=$(printf '%s' "$RAW" | tail -n1)
              APPS=$(printf '%s' "$RAW" | sed '$d')
              if [ "$HTTP" != "200" ]; then
                echo "Failed to list OAuth apps (HTTP $HTTP): $APPS" >&2
                exit 1
              fi

              APP_ID=$(printf '%s' "$APPS" | jq -r --arg name "$APP_NAME" '.[] | select(.name == $name) | .id' | head -n1)

              if [ -n "$APP_ID" ] && [ "$APP_ID" != "null" ]; then
                echo "OAuth app '$APP_NAME' exists in Forgejo (id=$APP_ID); deleting so we can recreate with a known secret"
                DEL_RAW=$(fetch DELETE "$API/$APP_ID")
                DEL_HTTP=$(printf '%s' "$DEL_RAW" | tail -n1)
                if [ "$DEL_HTTP" != "204" ] && [ "$DEL_HTTP" != "404" ]; then
                  echo "Failed to delete existing OAuth app (HTTP $DEL_HTTP)" >&2
                  exit 1
                fi
              fi

              echo "Creating OAuth app '$APP_NAME' in Forgejo"
              BODY=$(jq -nc --arg n "$APP_NAME" --arg r "$REDIRECT_URI" '{name:$n, redirect_uris:[$r], confidential_client:true}')
              RAW=$(fetch POST "$API" "$BODY")
              HTTP=$(printf '%s' "$RAW" | tail -n1)
              RESP=$(printf '%s' "$RAW" | sed '$d')
              if [ "$HTTP" != "201" ] && [ "$HTTP" != "200" ]; then
                echo "Failed to create OAuth app (HTTP $HTTP): $RESP" >&2
                exit 1
              fi

              CLIENT_ID=$(printf '%s' "$RESP" | jq -r '.client_id // empty')
              CLIENT_SECRET=$(printf '%s' "$RESP" | jq -r '.client_secret // empty')

              if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
                echo "Forgejo response missing client_id/secret: $RESP" >&2
                exit 1
              fi

              kubectl -n "$NS" create secret generic "$SECRET_NAME" \
                --from-literal=WOODPECKER_FORGEJO_CLIENT="$CLIENT_ID" \
                --from-literal=WOODPECKER_FORGEJO_SECRET="$CLIENT_SECRET" \
                --dry-run=client -o yaml | kubectl apply -f -

              echo "OAuth bootstrap complete."
            EOT
            ]
          }]
        }
      }
    }
  })

  depends_on = [
    kubernetes_role_binding.bootstrap,
    kubernetes_secret.bootstrap_input,
    terraform_data.forgejo_gate,
  ]
}

resource "terraform_data" "bootstrap_complete" {
  triggers_replace = {
    job_uid = kubectl_manifest.bootstrap_job.uid
  }

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      kubectl -n ${kubernetes_namespace.woodpecker.metadata[0].name} \
        wait --for=condition=complete \
        job/${local.bootstrap_job_name} --timeout=5m
    EOT
  }
}

resource "kubectl_manifest" "argo_app_woodpecker" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "woodpecker"
      namespace = local.argocd_namespace
    }
    spec = {
      project = "platform"
      source = {
        repoURL        = "ghcr.io/woodpecker-ci/helm"
        chart          = "woodpecker"
        targetRevision = var.woodpecker_chart_version
        helm = {
          releaseName = "woodpecker"
          values      = local.helm_values
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.woodpecker.metadata[0].name
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
    kubernetes_secret.woodpecker,
    terraform_data.bootstrap_complete,
  ]
}

resource "kubectl_manifest" "httproute_woodpecker" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "woodpecker"
      namespace = kubernetes_namespace.woodpecker.metadata[0].name
    }
    spec = {
      parentRefs = [
        {
          group     = "gateway.networking.k8s.io"
          kind      = "Gateway"
          name      = var.gateway_name
          namespace = var.gateway_namespace
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
              name = "woodpecker-server"
              port = 80
            }
          ]
        }
      ]
    }
  })

  depends_on = [
    kubectl_manifest.argo_app_woodpecker,
  ]
}

resource "terraform_data" "woodpecker_ready" {
  triggers_replace = [
    kubectl_manifest.argo_app_woodpecker.uid,
    kubectl_manifest.httproute_woodpecker.uid,
  ]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      set -euo pipefail
      kubectl wait --for=jsonpath='{.status.sync.status}'=Synced \
        application/woodpecker -n ${local.argocd_namespace} --timeout=10m
      kubectl -n ${kubernetes_namespace.woodpecker.metadata[0].name} \
        rollout status statefulset/woodpecker-server --timeout=10m
      kubectl -n ${kubernetes_namespace.woodpecker.metadata[0].name} \
        rollout status statefulset/woodpecker-agent --timeout=10m
      kubectl -n ${kubernetes_namespace.woodpecker.metadata[0].name} \
        wait --for=jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'=True \
        httproute/woodpecker --timeout=5m
      kubectl wait --for=jsonpath='{.status.health.status}'=Healthy \
        application/woodpecker -n ${local.argocd_namespace} --timeout=5m
    EOT
  }
}
