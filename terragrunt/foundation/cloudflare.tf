provider "cloudflare" {
  api_token = var.secrets.cloudflare_api_token
}

data "cloudflare_zones" "zone" {
  filter {
    name = var.domain
  }
}

resource "cloudflare_record" "nodes" {
  for_each = hcloud_server.nodes
  zone_id  = lookup(data.cloudflare_zones.zone.zones[0], "id")
  name     = "${each.value.name}.kube.${var.domain}"
  type     = "A"
  value    = each.value.ipv4_address
}

resource "cloudflare_record" "ingress" {
  zone_id = lookup(data.cloudflare_zones.zone.zones[0], "id")
  name    = "*.${var.domain}"
  type    = "A"
  value   = hcloud_floating_ip.floating_ip.ip_address
}
