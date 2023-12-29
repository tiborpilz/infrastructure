# Hetzner

This module takes care of creating the Hetzner Cloud servers and connecting them to external IPs.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_hcloud"></a> [hcloud](#requirement\_hcloud) | 1.39.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_hcloud"></a> [hcloud](#provider\_hcloud) | 1.39.0 |
| <a name="provider_local"></a> [local](#provider\_local) | n/a |
| <a name="provider_tls"></a> [tls](#provider\_tls) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [hcloud_floating_ip.floating_ip](https://registry.terraform.io/providers/hetznercloud/hcloud/1.39.0/docs/resources/floating_ip) | resource |
| [hcloud_server.nodes](https://registry.terraform.io/providers/hetznercloud/hcloud/1.39.0/docs/resources/server) | resource |
| [hcloud_ssh_key.terraform](https://registry.terraform.io/providers/hetznercloud/hcloud/1.39.0/docs/resources/ssh_key) | resource |
| [local_file.ssh_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [tls_private_key.ssh_key](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_hcloud_token"></a> [hcloud\_token](#input\_hcloud\_token) | The hetzner cloud token to use | `string` | n/a | yes |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Kubernetes nodes definitions | `map(any)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_floating_ip"></a> [floating\_ip](#output\_floating\_ip) | The floating IP address of the first worker node |
| <a name="output_nodes"></a> [nodes](#output\_nodes) | Hetzner Cloud VMs with their respective roles |
| <a name="output_ssh_key"></a> [ssh\_key](#output\_ssh\_key) | Generated SSH key for the Hetzner Cloud VMs |
