# Cloudflare

This module creates the DNS records for the Kubernetes cluster.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | 4.6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | 4.6.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [cloudflare_record.ingress](https://registry.terraform.io/providers/cloudflare/cloudflare/4.6.0/docs/resources/record) | resource |
| [cloudflare_record.nodes](https://registry.terraform.io/providers/cloudflare/cloudflare/4.6.0/docs/resources/record) | resource |
| [cloudflare_zones.zone](https://registry.terraform.io/providers/cloudflare/cloudflare/4.6.0/docs/data-sources/zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | The cloudflare api token to use | `string` | n/a | yes |
| <a name="input_domain"></a> [domain](#input\_domain) | The domain to use | `string` | n/a | yes |
| <a name="input_floating_ip"></a> [floating\_ip](#input\_floating\_ip) | The floating ip to use | `any` | n/a | yes |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Hetzner Cloud nodes | <pre>map(object({<br>    name          = string<br>    ipv4_address  = string<br>  }))</pre> | n/a | yes |

## Outputs

No outputs.
