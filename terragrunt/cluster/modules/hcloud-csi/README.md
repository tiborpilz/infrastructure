## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_local"></a> [local](#provider\_local) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_hcloud_csi"></a> [hcloud\_csi](#module\_hcloud\_csi) | ../download-manifest | n/a |

## Resources

| Name | Type |
|------|------|
| [local_file.hcloud_token](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_hcloud_csi_version"></a> [hcloud\_csi\_version](#input\_hcloud\_csi\_version) | The hcloud csi version to use | `string` | `"master"` | no |
| <a name="input_hcloud_token"></a> [hcloud\_token](#input\_hcloud\_token) | The hetzner cloud token to use | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_files"></a> [files](#output\_files) | n/a |
| <a name="output_manifest"></a> [manifest](#output\_manifest) | n/a |
