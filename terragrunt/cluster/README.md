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
| <a name="provider_local"></a> [local](#provider\_local) | 2.4.1 |
| <a name="provider_rke"></a> [rke](#provider\_rke) | 1.4.3 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cert_manager"></a> [cert\_manager](#module\_cert\_manager) | ./modules/cert-manager | n/a |
| <a name="module_hcloud_csi"></a> [hcloud\_csi](#module\_hcloud\_csi) | ./modules/hcloud-csi | n/a |
| <a name="module_ingress_nginx"></a> [ingress\_nginx](#module\_ingress\_nginx) | ./modules/ingress-nginx | n/a |
| <a name="module_keycloak"></a> [keycloak](#module\_keycloak) | ./modules/keycloak | n/a |
| <a name="module_metallb"></a> [metallb](#module\_metallb) | ./modules/metallb | n/a |

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
| <a name="input_cert_manager_version"></a> [cert\_manager\_version](#input\_cert\_manager\_version) | The cert-manager version to use | `string` | n/a | yes |
| <a name="input_cluster_connection"></a> [cluster\_connection](#input\_cluster\_connection) | The cluster connection to use | `map(string)` | `{}` | no |
| <a name="input_domain"></a> [domain](#input\_domain) | The domain to use | `string` | n/a | yes |
| <a name="input_email"></a> [email](#input\_email) | The email used for letsencrypt | `string` | n/a | yes |
| <a name="input_gitlab_infrastructure_project_id"></a> [gitlab\_infrastructure\_project\_id](#input\_gitlab\_infrastructure\_project\_id) | The id of the infrastructure project in gitlab | `any` | n/a | yes |
| <a name="input_ingress_ips"></a> [ingress\_ips](#input\_ingress\_ips) | List of ingress IPs to use for metallb. | `list(string)` | `[]` | no |
| <a name="input_ingress_nginx_version"></a> [ingress\_nginx\_version](#input\_ingress\_nginx\_version) | The ingress-nginx version to use | `string` | n/a | yes |
| <a name="input_keycloak_version"></a> [keycloak\_version](#input\_keycloak\_version) | The keycloak version to use | `string` | n/a | yes |
| <a name="input_kube_config_yaml"></a> [kube\_config\_yaml](#input\_kube\_config\_yaml) | The kube config yaml to use | `string` | `""` | no |
| <a name="input_metallb_version"></a> [metallb\_version](#input\_metallb\_version) | The metallb version to use | `string` | n/a | yes |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Kubernetes nodes. | <pre>map(object({<br>    role         = string,<br>    ipv4_address = string<br>  }))</pre> | n/a | yes |
| <a name="input_rke_kubernetes_version"></a> [rke\_kubernetes\_version](#input\_rke\_kubernetes\_version) | The (rke) kubernetes version to use | `string` | n/a | yes |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | The secrets to use | `map(string)` | `{}` | no |
| <a name="input_ssh_key"></a> [ssh\_key](#input\_ssh\_key) | SSH key to use for the k8s nodes. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_connection"></a> [cluster\_connection](#output\_cluster\_connection) | n/a |
| <a name="output_kube_config_yaml"></a> [kube\_config\_yaml](#output\_kube\_config\_yaml) | n/a |
