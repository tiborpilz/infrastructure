## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_local"></a> [local](#provider\_local) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [local_file.ingress_nginx](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_hsts"></a> [hsts](#input\_hsts) | Whether to enable HSTS | `bool` | `true` | no |
| <a name="input_ingress_nginx_version"></a> [ingress\_nginx\_version](#input\_ingress\_nginx\_version) | The ingress-nginx version to use | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_files"></a> [files](#output\_files) | n/a |
