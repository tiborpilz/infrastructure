/**
 * # Cloudflare
 *
 * This module creates the DNS records for the Kubernetes cluster.
 */

terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.21.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zones" "zone" {
  filter {
    name = var.domain
  }
}

resource "cloudflare_record" "nodes" {
  for_each = var.nodes
  zone_id  = lookup(data.cloudflare_zones.zone.zones[0], "id")
  name     = "${each.value.name}.kube.${var.domain}"
  type     = "A"
  value    = each.value.ipv4_address
}

resource "cloudflare_record" "ingress" {
  zone_id = lookup(data.cloudflare_zones.zone.zones[0], "id")
  name    = "*.${var.domain}"
  type    = "A"
  value   = var.floating_ip
}
