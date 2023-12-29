# Foundation

This module creates the foundation for a Kubernetes cluster.
Based on a node config, it will create Hetzner Cloud servers and connect external IPs to them.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_rke"></a> [rke](#requirement\_rke) | 1.4.1 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cloudflare"></a> [cloudflare](#module\_cloudflare) | ./cloudflare | n/a |
| <a name="module_hetzner"></a> [hetzner](#module\_hetzner) | ./hetzner | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_domain"></a> [domain](#input\_domain) | The domain to use | `string` | n/a | yes |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Node configuration | `any` | n/a | yes |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | Encrypted secrets | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_domain"></a> [domain](#output\_domain) | n/a |
| <a name="output_ingress_ips"></a> [ingress\_ips](#output\_ingress\_ips) | List of ingress IPs. |
| <a name="output_nodes"></a> [nodes](#output\_nodes) | Hetzner Cloud VMs with their respective roles. |
| <a name="output_ssh_key"></a> [ssh\_key](#output\_ssh\_key) | The generated SSH key for connecting to the nodes. |
