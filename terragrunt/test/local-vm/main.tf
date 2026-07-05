# Renders the real bootstrap module (the cluster's inline manifests) with
# throwaway credentials into a Talos machine-config patch for a local VM
# cluster. Cloud-coupled manifests are dropped; everything else is exactly
# what production nodes boot with. Consumed by setup/local-talos-cluster.sh.

variable "kubernetes_version" {
  description = "kube_version for helm template rendering. Matches the production default."
  type        = string
  default     = "1.30.0"
}

variable "domain" {
  description = "Stand-in domain for Gateway hostnames and the ClusterIssuer."
  type        = string
  default     = "local.test"
}

variable "skip_manifests" {
  description = "Inline manifests that only make sense against real cloud APIs."
  type        = list(string)
  default = [
    "ns-hcloud-csi",
    "hcloud-ccm-secret",
    "hcloud-ccm",
    "hcloud-csi-secret",
    "hcloud-csi",
    "ns-external-dns",
    "external-dns-secret",
    "external-dns-crd",
    "external-dns",
  ]
}

provider "helm" {}

module "bootstrap" {
  source = "../../cluster/talos/bootstrap"

  kubernetes_version   = var.kubernetes_version
  domain               = var.domain
  location             = "fsn1"
  admin_email          = "ci@${var.domain}"
  hcloud_token         = "local-test-dummy"
  network_name         = "local-test"
  cloudflare_api_token = "local-test-dummy"
  argocd_age_key       = "local-test-dummy"
}

locals {
  manifests = [
    for m in module.bootstrap.inline_manifests : m
    if !contains(var.skip_manifests, m.name)
  ]

  machine_patch = yamlencode({
    cluster = {
      inlineManifests = local.manifests
    }
  })
}

resource "local_file" "machine_patch" {
  filename        = "${path.module}/out/local-bootstrap-patch.yaml"
  file_permission = "0644"
  content         = local.machine_patch
}

output "included_manifests" {
  description = "Names of the inline manifests included in the patch."
  value       = [for m in local.manifests : m.name]
}
