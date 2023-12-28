## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_keycloak"></a> [keycloak](#requirement\_keycloak) | 4.1.0 |
| <a name="requirement_rancher2"></a> [rancher2](#requirement\_rancher2) | 3.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | n/a |
| <a name="provider_http"></a> [http](#provider\_http) | n/a |
| <a name="provider_keycloak"></a> [keycloak](#provider\_keycloak) | 4.1.0 |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |
| <a name="provider_rancher2.admin"></a> [rancher2.admin](#provider\_rancher2.admin) | 3.0.0 |
| <a name="provider_rancher2.bootstrap"></a> [rancher2.bootstrap](#provider\_rancher2.bootstrap) | 3.0.0 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.rancher](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [keycloak_openid_audience_protocol_mapper.rancher_audience_mapper](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/openid_audience_protocol_mapper) | resource |
| [keycloak_openid_client.rancher_oidc](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/openid_client) | resource |
| [keycloak_openid_client_default_scopes.client_default_scopes](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/openid_client_default_scopes) | resource |
| [keycloak_openid_client_scope.rancher_oidc](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/openid_client_scope) | resource |
| [keycloak_openid_group_membership_protocol_mapper.rancher_group_mapper](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/openid_group_membership_protocol_mapper) | resource |
| [keycloak_openid_group_membership_protocol_mapper.rancher_group_path_mapper](https://registry.terraform.io/providers/mrparkers/keycloak/4.1.0/docs/resources/openid_group_membership_protocol_mapper) | resource |
| [null_resource.configure_keycloak_oidcs](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [rancher2_bootstrap.admin](https://registry.terraform.io/providers/rancher/rancher2/3.0.0/docs/resources/bootstrap) | resource |
| [rancher2_global_role.admin](https://registry.terraform.io/providers/rancher/rancher2/3.0.0/docs/resources/global_role) | resource |
| [rancher2_token.auth](https://registry.terraform.io/providers/rancher/rancher2/3.0.0/docs/resources/token) | resource |
| [tls_private_key.rancher](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [http_http.keycloak_saml](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_domain"></a> [domain](#input\_domain) | The domain to use | `string` | n/a | yes |
| <a name="input_email"></a> [email](#input\_email) | The email address to use for the certificate | `string` | n/a | yes |
| <a name="input_keycloak_realm"></a> [keycloak\_realm](#input\_keycloak\_realm) | The Keycloak realm to use | `any` | n/a | yes |
| <a name="input_rancher_initial_password"></a> [rancher\_initial\_password](#input\_rancher\_initial\_password) | The initial password to use for rancher | `string` | n/a | yes |
| <a name="input_rancher_version"></a> [rancher\_version](#input\_rancher\_version) | The rancher (helm chart) version to use | `string` | n/a | yes |

## Outputs

No outputs.
