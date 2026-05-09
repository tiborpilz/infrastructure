locals {
  argocd_namespace          = "argocd"
  velero_namespace          = "velero"
  cluster_backup_namespace  = "cluster-backup"
  velero_credentials_secret = "velero-s3-credentials"
  etcd_credentials_secret   = "etcd-s3-credentials"
  talosconfig_secret        = "talosconfig"

  # AWS-credentials-file body. Velero's velero-plugin-for-aws reads this from
  # the Secret key `cloud`.
  aws_credentials_file = <<-EOT
    [default]
    aws_access_key_id=${var.hcloud_s3_access_key}
    aws_secret_access_key=${var.hcloud_s3_secret_key}
  EOT

  s3_endpoint = "https://${var.hcloud_object_storage_region}.your-objectstorage.com"
}

# ---------------------------------------------------------------------------
# S3 bucket on Hetzner Object Storage. Single bucket with `velero/` and
# `etcd/` prefixes — Velero takes a `prefix` field on the BSL, the etcd
# CronJob writes under `etcd/` directly.
#
# No bucket versioning: Hetzner Object Storage versioning is paid, and
# Velero's own retention (TTL on schedules) is sufficient. The etcd
# CronJob handles its own retention via list+rm of objects older than
# var.etcd_snapshot_retention_days.
# ---------------------------------------------------------------------------

resource "minio_s3_bucket" "backups" {
  bucket = var.bucket_name
  acl    = "private"
}

# ---------------------------------------------------------------------------
# Velero namespace + S3 credentials Secret.
# Velero's chart looks for a Secret with key `cloud` containing the
# AWS-credentials-file body. We ship that Secret via TF so the chart's
# `credentials.existingSecret` mode works.
# ---------------------------------------------------------------------------

resource "kubernetes_namespace" "velero" {
  metadata {
    name = local.velero_namespace
    labels = {
      "managed-by" = "terragrunt"
    }
  }
}

resource "kubernetes_secret" "velero_s3_creds" {
  metadata {
    name      = local.velero_credentials_secret
    namespace = kubernetes_namespace.velero.metadata[0].name
  }

  data = {
    cloud = local.aws_credentials_file
  }
}

# ---------------------------------------------------------------------------
# Velero — Argo CD Application.
# Helm chart from vmware-tanzu/helm-charts. Backup Storage Location and
# schedules come through var.velero_values (rendered in the env layer).
# ---------------------------------------------------------------------------

resource "kubectl_manifest" "argo_app_velero" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "velero"
      namespace = local.argocd_namespace
    }
    spec = {
      project = "platform"
      source = {
        repoURL        = "https://vmware-tanzu.github.io/helm-charts"
        chart          = "velero"
        targetRevision = var.velero_chart_version
        helm = {
          values = var.velero_values
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.velero.metadata[0].name
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
    kubernetes_secret.velero_s3_creds,
  ]
}

# ---------------------------------------------------------------------------
# Talos etcd snapshot — separate namespace so its blast radius doesn't mix
# with Velero's. The CronJob runs talosctl in-cluster to capture an etcd
# snapshot and uploads it to the same bucket under etcd/.
#
# Pod-security: privileged. talosctl must reach the Talos API on the host's
# port 50000; using hostNetwork avoids needing to coordinate which CP node's
# public IP to dial (works for single-node and HA the same way).
# ---------------------------------------------------------------------------

resource "kubernetes_namespace" "cluster_backup" {
  metadata {
    name = local.cluster_backup_namespace
    labels = {
      "managed-by" = "terragrunt"

      # hostNetwork is restricted in baseline/restricted PSS. The snapshot
      # CronJob needs it to talk to Talos API on 127.0.0.1:50000.
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

resource "kubernetes_secret" "talosconfig" {
  metadata {
    name      = local.talosconfig_secret
    namespace = kubernetes_namespace.cluster_backup.metadata[0].name
  }

  data = {
    talosconfig = var.talosconfig_raw
  }
}

resource "kubernetes_secret" "etcd_snapshot_s3_creds" {
  metadata {
    name      = local.etcd_credentials_secret
    namespace = kubernetes_namespace.cluster_backup.metadata[0].name
  }

  data = {
    AWS_ACCESS_KEY_ID     = var.hcloud_s3_access_key
    AWS_SECRET_ACCESS_KEY = var.hcloud_s3_secret_key
  }
}

resource "kubectl_manifest" "cronjob_etcd_snapshot" {
  yaml_body = yamlencode({
    apiVersion = "batch/v1"
    kind       = "CronJob"
    metadata = {
      name      = "etcd-snapshot"
      namespace = kubernetes_namespace.cluster_backup.metadata[0].name
    }
    spec = {
      schedule                   = var.etcd_snapshot_schedule
      concurrencyPolicy          = "Forbid"
      successfulJobsHistoryLimit = 1
      failedJobsHistoryLimit     = 3
      jobTemplate = {
        spec = {
          backoffLimit = 2
          template = {
            spec = {
              restartPolicy = "OnFailure"
              hostNetwork   = true

              # Schedule on a control-plane node so 127.0.0.1:50000 reaches
              # Talos's apid. With allow_scheduling_on_control_planes = true
              # (single-node default) this matches every node anyway.
              tolerations = [
                {
                  key      = "node-role.kubernetes.io/control-plane"
                  operator = "Exists"
                  effect   = "NoSchedule"
                },
              ]
              nodeSelector = {
                "node-role.kubernetes.io/control-plane" = ""
              }

              volumes = [
                {
                  name = "talosconfig"
                  secret = {
                    secretName = kubernetes_secret.talosconfig.metadata[0].name
                  }
                },
                {
                  name     = "snapshot"
                  emptyDir = {}
                },
              ]

              containers = [
                {
                  name            = "snapshot"
                  image           = var.etcd_snapshotter_image
                  imagePullPolicy = "IfNotPresent"

                  envFrom = [
                    {
                      secretRef = {
                        name = kubernetes_secret.etcd_snapshot_s3_creds.metadata[0].name
                      }
                    },
                  ]

                  env = [
                    { name = "TALOS_NODE", value = "127.0.0.1" },
                    { name = "S3_ENDPOINT", value = local.s3_endpoint },
                    { name = "BUCKET", value = minio_s3_bucket.backups.bucket },
                    { name = "RETENTION_DAYS", value = tostring(var.etcd_snapshot_retention_days) },
                  ]

                  volumeMounts = [
                    { name = "talosconfig", mountPath = "/talos", readOnly = true },
                    { name = "snapshot", mountPath = "/tmp/snap" },
                  ]

                  command = ["/bin/sh", "-c"]
                  args = [<<-EOT
                    set -euo pipefail

                    SNAPSHOT="/tmp/snap/db.$(date -u +%Y%m%dT%H%M%SZ).snapshot"

                    talosctl --talosconfig /talos/talosconfig --nodes "$${TALOS_NODE}" \
                      etcd snapshot "$${SNAPSHOT}"

                    aws --endpoint-url "$${S3_ENDPOINT}" s3 cp \
                      "$${SNAPSHOT}" \
                      "s3://$${BUCKET}/etcd/$(basename "$${SNAPSHOT}")"

                    # Retention: list etcd/ objects older than RETENTION_DAYS and delete.
                    CUTOFF=$(date -u -d "$${RETENTION_DAYS} days ago" +%s 2>/dev/null \
                             || date -u -v-$${RETENTION_DAYS}d +%s)
                    aws --endpoint-url "$${S3_ENDPOINT}" s3api list-objects-v2 \
                      --bucket "$${BUCKET}" --prefix etcd/ \
                      --query 'Contents[].[Key,LastModified]' --output text 2>/dev/null \
                      | while read -r KEY LAST_MODIFIED; do
                          [ -z "$${KEY:-}" ] && continue
                          OBJ_TS=$(date -u -d "$${LAST_MODIFIED}" +%s 2>/dev/null \
                                   || date -u -j -f "%Y-%m-%dT%H:%M:%S" "$${LAST_MODIFIED%.*}" +%s)
                          if [ "$${OBJ_TS}" -lt "$${CUTOFF}" ]; then
                            echo "deleting old snapshot: $${KEY}"
                            aws --endpoint-url "$${S3_ENDPOINT}" s3 rm "s3://$${BUCKET}/$${KEY}"
                          fi
                        done
                  EOT
                  ]
                },
              ]
            }
          }
        }
      }
    }
  })
}

# ---------------------------------------------------------------------------
# Readiness gate. Same shape as 35-platform-data: wait for Argo to report
# the Velero Application Healthy, then a kubectl-level sanity check on the
# CronJob existing.
# ---------------------------------------------------------------------------

resource "terraform_data" "velero_ready" {
  triggers_replace = [
    kubectl_manifest.argo_app_velero.uid,
    kubectl_manifest.cronjob_etcd_snapshot.uid,
  ]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      set -euo pipefail
      kubectl wait --for=jsonpath='{.status.health.status}=Healthy' \
        application/velero -n ${local.argocd_namespace} --timeout=10m
      kubectl wait --for=condition=Available deployment/velero \
        -n ${local.velero_namespace} --timeout=5m
      kubectl get cronjob etcd-snapshot -n ${local.cluster_backup_namespace} >/dev/null
    EOT
  }
}
