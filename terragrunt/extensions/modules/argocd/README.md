## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_gitlab"></a> [gitlab](#requirement\_gitlab) | 16.6.0 |
| <a name="requirement_keycloak"></a> [keycloak](#requirement\_keycloak) | 4.1.0 |
| <a name="requirement_kustomization"></a> [kustomization](#requirement\_kustomization) | 0.9.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_gitlab"></a> [gitlab](#provider\_gitlab) | 16.6.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | n/a |
| <a name="provider_keycloak"></a> [keycloak](#provider\_keycloak) | 4.1.0 |
| <a name="provider_local"></a> [local](#provider\_local) | n/a |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |
| <a name="provider_template"></a> [template](#provider\_template) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [gitlab_project_access_token.infrastructure_argocd](https://registry.terraform.io/providers/gitlabhq/gitlab/16.6.0/docs/resources/project_access_token) | resource |
| [helm_release.argocd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [keycloak_generic_protocol_mapper.argo_groups](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/generic_protocol_mapper) | resource |
| [keycloak_openid_client.argocd](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/openid_client) | resource |
| [keycloak_openid_client_default_scopes.argo_default_scopes](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/openid_client_default_scopes) | resource |
| [keycloak_openid_group_membership_protocol_mapper.argo_group_membership](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/openid_group_membership_protocol_mapper) | resource |
| [local_file.kube_config](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.manifests](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.apply_manifests](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [gitlab_project.infrastructure](https://registry.terraform.io/providers/gitlabhq/gitlab/16.6.0/docs/data-sources/project) | data source |
| [template_file.argocd_apps](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.argocd_values](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |
| [template_file.repo_creds](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_argocd_version"></a> [argocd\_version](#input\_argocd\_version) | The argocd (helm chart) version to use | `any` | n/a | yes |
| <a name="input_domain"></a> [domain](#input\_domain) | The domain to use | `any` | n/a | yes |
| <a name="input_gitlab_infrastructure_project_id"></a> [gitlab\_infrastructure\_project\_id](#input\_gitlab\_infrastructure\_project\_id) | The id of the infrastructure project in gitlab | `any` | n/a | yes |
| <a name="input_keycloak_realm"></a> [keycloak\_realm](#input\_keycloak\_realm) | The Keycloak realm id to use | `any` | n/a | yes |
| <a name="input_kube_config_yaml"></a> [kube\_config\_yaml](#input\_kube\_config\_yaml) | The kube config yaml to use | `any` | n/a | yes |

## Outputs

No outputs.
