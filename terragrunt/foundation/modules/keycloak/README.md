## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_local"></a> [local](#provider\_local) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_keycloak_operator"></a> [keycloak\_operator](#module\_keycloak\_operator) | ../download-manifest | n/a |
| <a name="module_keycloak_realm_operator"></a> [keycloak\_realm\_operator](#module\_keycloak\_realm\_operator) | ../download-manifest | n/a |

## Resources

| Name | Type |
|------|------|
| [local_file.keycloak](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.namespace](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_default_password"></a> [default\_password](#input\_default\_password) | The default password to use | `string` | `"admin"` | no |
| <a name="input_default_username"></a> [default\_username](#input\_default\_username) | The default username to use | `string` | `"admin"` | no |
| <a name="input_domain"></a> [domain](#input\_domain) | The domain to use | `string` | n/a | yes |
| <a name="input_keycloak_version"></a> [keycloak\_version](#input\_keycloak\_version) | The keycloak version to use | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_files"></a> [files](#output\_files) | n/a |
| <a name="output_manifest"></a> [manifest](#output\_manifest) | n/a |
