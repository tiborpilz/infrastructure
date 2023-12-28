# Foundation

This module creates the foundation for a Kubernetes cluster.
Based on a node config, it will create Hetzner Cloud servers and connect external IPs to them.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | 4.6.0 |
| <a name="requirement_hcloud"></a> [hcloud](#requirement\_hcloud) | 1.39.0 |
| <a name="requirement_rke"></a> [rke](#requirement\_rke) | 1.4.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | 4.6.0 |
| <a name="provider_hcloud"></a> [hcloud](#provider\_hcloud) | 1.39.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.4.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | 4.0.4 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [cloudflare_record.ingress](https://registry.terraform.io/providers/cloudflare/cloudflare/4.6.0/docs/resources/record) | resource |
| [cloudflare_record.nodes](https://registry.terraform.io/providers/cloudflare/cloudflare/4.6.0/docs/resources/record) | resource |
| [hcloud_floating_ip.floating_ip](https://registry.terraform.io/providers/hetznercloud/hcloud/1.39.0/docs/resources/floating_ip) | resource |
| [hcloud_server.nodes](https://registry.terraform.io/providers/hetznercloud/hcloud/1.39.0/docs/resources/server) | resource |
| [hcloud_ssh_key.terraform](https://registry.terraform.io/providers/hetznercloud/hcloud/1.39.0/docs/resources/ssh_key) | resource |
| [local_file.ssh_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [tls_private_key.ssh_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [cloudflare_zones.zone](https://registry.terraform.io/providers/cloudflare/cloudflare/4.6.0/docs/data-sources/zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_docker_login"></a> [docker\_login](#input\_docker\_login) | Whether to login to docker | `bool` | `false` | no |
| <a name="input_domain"></a> [domain](#input\_domain) | The domain to use | `string` | n/a | yes |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Node configuration | `any` | n/a | yes |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | Encrypted secrets | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_domain"></a> [domain](#output\_domain) | n/a |
| <a name="output_ingress_ips"></a> [ingress\_ips](#output\_ingress\_ips) | List of ingress IPs. |
| <a name="output_nodes"></a> [nodes](#output\_nodes) | Hetzner Cloud VMs with their respective roles. |
| <a name="output_ssh_key"></a> [ssh\_key](#output\_ssh\_key) | n/a |
