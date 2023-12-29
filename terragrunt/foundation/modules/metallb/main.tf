variable "ips" {
  type    = list(string)
  default = []
}

variable "metallb_version" {
  type        = string
  description = "The metallb version to use"
  default     = "main"
}

module "kustomization" {
  source = "../kustomization"
  kustomize_dir = "${path.module}/kustomize"
  overlay = {
    apiVersion: "kustomize.config.k8s.io/v1beta1",
    kind: "Kustomization",
    resources: [
      "../base",
    ],
    patches: [
      {
        target: {
          kind: "IPAddressPool",
          name: "default"
        },
        patch: yamlencode([{
          op: "replace",
          path: "spec/addresses",
          value: var.ips
        }])
      }
    ]
  }
}

output "files" {
  value = [module.kustomization.manifests.filename]
}
