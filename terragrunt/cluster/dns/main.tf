data "cloudflare_zone" "this" {
  name = local.zone
}

locals {
  zone = coalesce(var.zone, var.domain)

  # Record names are relative to the zone: empty at the apex, ".test" when
  # the domain is test.<zone>.
  label_suffix = var.domain == local.zone ? "" : ".${trimsuffix(var.domain, ".${local.zone}")}"

  subdomain = "kube"

  node_records = merge(
    { for key, value in var.nodes.control_plane : key => value.public_ipv4 },
    { for key, value in var.nodes.workers : key => value.public_ipv4 },
  )
}

resource "cloudflare_record" "wildcard" {
  zone_id = data.cloudflare_zone.this.id
  name    = "*${local.label_suffix}"
  type    = "A"
  content = var.lb_ipv4
  ttl     = 60
  proxied = false
  comment = "Wildcard → ingress floating IP (Terraform-managed)."
}

resource "cloudflare_record" "node" {
  for_each = local.node_records

  zone_id = data.cloudflare_zone.this.id
  name    = "${each.key}.${local.subdomain}${local.label_suffix}"
  type    = "A"
  content = each.value
  ttl     = 60
  proxied = false
  comment = "Cluster node ${each.key} (terragrunt-managed)."
}
