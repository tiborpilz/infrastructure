# Cluster

This module creates a kubernetes cluster using rke.
It also installs argocd, keycloak, cert-manager, ingress-nginx and metallb.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_gitlab"></a> [gitlab](#requirement\_gitlab) | 16.6.0 |
| <a name="requirement_rke"></a> [rke](#requirement\_rke) | 1.4.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_gitlab"></a> [gitlab](#provider\_gitlab) | 16.6.0 |
| <a name="provider_local"></a> [local](#provider\_local) | n/a |
| <a name="provider_rke"></a> [rke](#provider\_rke) | 1.4.3 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cert_manager"></a> [cert\_manager](#module\_cert\_manager) | ../cert-manager | n/a |
| <a name="module_hcloud_csi"></a> [hcloud\_csi](#module\_hcloud\_csi) | ../hcloud-csi | n/a |
| <a name="module_ingress_nginx"></a> [ingress\_nginx](#module\_ingress\_nginx) | ../ingress-nginx | n/a |
| <a name="module_keycloak"></a> [keycloak](#module\_keycloak) | ../keycloak | n/a |
| <a name="module_metallb"></a> [metallb](#module\_metallb) | ../metallb | n/a |

## Resources

| Name | Type |
|------|------|
| [gitlab_project_access_token.registry_rke](https://registry.terraform.io/providers/gitlabhq/gitlab/16.6.0/docs/resources/project_access_token) | resource |
| [local_file.kube_cluster_yaml](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.rke_cluster_yaml](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [rke_cluster.cluster](https://registry.terraform.io/providers/rancher/rke/1.4.3/docs/resources/cluster) | resource |
| [gitlab_project.infrastructure](https://registry.terraform.io/providers/gitlabhq/gitlab/16.6.0/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_domain"></a> [domain](#input\_domain) | The domain to use | `string` | n/a | yes |
| <a name="input_email"></a> [email](#input\_email) | The email to use for letsencrypt | `string` | n/a | yes |
| <a name="input_gitlab_infrastructure_project_id"></a> [gitlab\_infrastructure\_project\_id](#input\_gitlab\_infrastructure\_project\_id) | The id of the infrastructure project in gitlab | `any` | n/a | yes |
| <a name="input_gitlab_token"></a> [gitlab\_token](#input\_gitlab\_token) | The gitlab token to use | `string` | n/a | yes |
| <a name="input_hcloud_token"></a> [hcloud\_token](#input\_hcloud\_token) | The hcloud token to use | `string` | n/a | yes |
| <a name="input_ingress_ips"></a> [ingress\_ips](#input\_ingress\_ips) | List of ingress IPs to use for metallb. | `list(string)` | `[]` | no |
| <a name="input_keycloak_admin_password"></a> [keycloak\_admin\_password](#input\_keycloak\_admin\_password) | The keycloak admin password to use | `string` | n/a | yes |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Hetzner Cloud nodes | <pre>map(object({<br>    name          = string<br>    ipv4_address  = string<br>    labels        = map(string)<br>  }))</pre> | n/a | yes |
| <a name="input_ssh_key"></a> [ssh\_key](#input\_ssh\_key) | SSH key to use for the k8s nodes. | `map(string)` | n/a | yes |
| <a name="input_versions"></a> [versions](#input\_versions) | Versions for the various components to use | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_connection"></a> [cluster\_connection](#output\_cluster\_connection) | n/a |
| <a name="output_kube_config_yaml"></a> [kube\_config\_yaml](#output\_kube\_config\_yaml) | n/a |
