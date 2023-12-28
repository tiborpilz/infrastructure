## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_http"></a> [http](#provider\_http) | n/a |
| <a name="provider_local"></a> [local](#provider\_local) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [local_file.manifest](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [http_http.manifests](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_namespace"></a> [namespace](#input\_namespace) | optional namespace to add to each resource in the manifest | `string` | `"kube-system"` | no |
| <a name="input_output_file"></a> [output\_file](#input\_output\_file) | File to write the manifest to | `string` | `null` | no |
| <a name="input_templates"></a> [templates](#input\_templates) | Templates to render | <pre>list(object({<br>    template = string,<br>    values   = any,<br>  }))</pre> | `[]` | no |
| <a name="input_urls"></a> [urls](#input\_urls) | The urls of the yaml manifests (use this for multiple manifests) | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_file"></a> [file](#output\_file) | The manifest file |
| <a name="output_manifest"></a> [manifest](#output\_manifest) | The addon as list of manifests with namespace, encoded as yaml, separated by --- |
