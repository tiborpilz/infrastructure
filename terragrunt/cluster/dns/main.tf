data "cloudflare_zone" "this" {
  name = var.domain
}

locals {
  subdomain = "kube"

  node_records = merge(
    { for key, value in var.nodes.control_plane : key => value.public_ipv4 },
    { for key, value in var.nodes.workers : key => value.public_ipv4 },
  )
}

resource "cloudflare_record" "node" {
  for_each = local.node_records

  zone_id = data.cloudflare_zone.this.id
  name    = "${each.key}.${local.subdomain}"
  type    = "A"
  content = each.value
  ttl     = 60
  proxied = false
  comment = "Cluster node ${each.key} (terragrunt-managed)."
}
