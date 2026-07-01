locals {
  all_manifests = concat(
    local.gateway_pre_manifests,
    local.cilium_manifests,
    local.hcloud_manifests,
    local.argocd_manifests,
    local.cert_manager_manifests,
    local.external_dns_manifests,
    local.sops_manifests,
    local.gateway_post_manifests,
  )
}

output "inline_manifests" {
  description = "Inline manifests for Talos bootstrap."
  value       = local.all_manifests
}

output "rendered_yaml" {
  description = "All bootstrap manifests concatenated as a multi-document YAML string. Write to a file for inspection."
  value       = join("\n---\n", [for m in local.all_manifests : "# ${m.name}\n${m.contents}"])
}
