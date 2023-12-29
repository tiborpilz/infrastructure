variable "email" {
  type = string
}

variable "cert_manager_version" {
  type        = string
  description = "The cert-manager version to use"
  default     = "main"
}

module "kustomization" {
  source        = "../kustomization"
  kustomize_dir = "${path.module}/kustomize"
  overlay = {
    apiVersion : "kustomize.config.k8s.io/v1beta1",
    kind : "Kustomization",
    resources : [
      "../base",
    ],
    patches : [
      {
        target : {
          kind : "ClusterIssuer",
          name : "letsencrypt-clusteriusser"
        },
        patch : yamlencode([{
          op : "add",
          path : "/spec/acme/email",
          value : var.email
        }])
      }
    ]
  }
}

output "files" {
  value = [module.kustomization.manifests.filename]
}
