## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_local"></a> [local](#provider\_local) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_metallb"></a> [metallb](#module\_metallb) | ../download-manifest | n/a |

## Resources

| Name | Type |
|------|------|
| [local_file.metallb_address_pool](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ips"></a> [ips](#input\_ips) | n/a | `list(string)` | `[]` | no |
| <a name="input_metallb_version"></a> [metallb\_version](#input\_metallb\_version) | The metallb version to use | `string` | `"main"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_files"></a> [files](#output\_files) | n/a |
