## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_keycloak"></a> [keycloak](#requirement\_keycloak) | 4.1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | n/a |
| <a name="provider_keycloak"></a> [keycloak](#provider\_keycloak) | 4.1.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | n/a |
| <a name="provider_template"></a> [template](#provider\_template) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.oauth2_proxy](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [keycloak_generic_protocol_mapper.k8s_groups](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/generic_protocol_mapper) | resource |
| [keycloak_group.admin](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/group) | resource |
| [keycloak_group_memberships.admin_membership](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/group_memberships) | resource |
| [keycloak_openid_client.kubernetes](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/openid_client) | resource |
| [keycloak_openid_client.oauth2_proxy](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/openid_client) | resource |
| [keycloak_openid_client_default_scopes.k8s_default_scopes](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/openid_client_default_scopes) | resource |
| [keycloak_openid_client_scope.groups](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/openid_client_scope) | resource |
| [keycloak_openid_group_membership_protocol_mapper.group_membership_mapper](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/openid_group_membership_protocol_mapper) | resource |
| [keycloak_realm.default](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/realm) | resource |
| [keycloak_user.users](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/user) | resource |
| [kubernetes_cluster_role_binding.oidc-cluster-admin](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [keycloak_realm.master](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/data-sources/realm) | data source |
| [keycloak_role.admin](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/data-sources/role) | data source |
| [template_file.oauth2_proxy_values](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | The admin password to use for keycloak | `string` | n/a | yes |
| <a name="input_domain"></a> [domain](#input\_domain) | The domain to use | `string` | n/a | yes |
| <a name="input_users"></a> [users](#input\_users) | n/a | <pre>map(object({<br>    username   = string<br>    password   = string<br>    email      = string<br>    is_admin   = bool<br>    first_name = string<br>    last_name  = string<br>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_realm"></a> [realm](#output\_realm) | n/a |
