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

resource "cloudflare_record" "wildcard" {
  zone_id = data.cloudflare_zone.this.id
  name    = "*"
  type    = "A"
  content = var.lb_ipv4
  ttl     = 60
  proxied = false
  comment = "Wildcard → ingress floating IP (Terraform-managed)."
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
