# Extensions

This module installs extensions to an already existing Kubernetes cluster.
For everything to work, the cluster needs to have Keycloak installed and set up.

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_argocd"></a> [argocd](#requirement\_argocd) | 6.0.3 |
| <a name="requirement_gitlab"></a> [gitlab](#requirement\_gitlab) | 16.6.0 |
| <a name="requirement_keycloak"></a> [keycloak](#requirement\_keycloak) | 4.1.0 |
| <a name="requirement_kustomization"></a> [kustomization](#requirement\_kustomization) | 0.9.5 |
| <a name="requirement_rancher2"></a> [rancher2](#requirement\_rancher2) | 3.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_argocd"></a> [argocd](#module\_argocd) | ./modules/argocd | n/a |
| <a name="module_keycloak"></a> [keycloak](#module\_keycloak) | ./modules/keycloak | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_argocd_version"></a> [argocd\_version](#input\_argocd\_version) | The argocd (helm chart) version to use | `string` | n/a | yes |
| <a name="input_cluster_connection"></a> [cluster\_connection](#input\_cluster\_connection) | The cluster connection to use | `map(string)` | `{}` | no |
| <a name="input_domain"></a> [domain](#input\_domain) | The domain to use | `string` | n/a | yes |
| <a name="input_email"></a> [email](#input\_email) | The email used for letsencrypt | `string` | n/a | yes |
| <a name="input_gitlab_infrastructure_project_id"></a> [gitlab\_infrastructure\_project\_id](#input\_gitlab\_infrastructure\_project\_id) | The id of the infrastructure project in gitlab | `any` | n/a | yes |
| <a name="input_kube_config_yaml"></a> [kube\_config\_yaml](#input\_kube\_config\_yaml) | The kube config yaml to use | `string` | `""` | no |
| <a name="input_rancher_version"></a> [rancher\_version](#input\_rancher\_version) | The rancher (helm chart) version to use | `string` | n/a | yes |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | The secrets to use | `map(string)` | `{}` | no |
| <a name="input_users"></a> [users](#input\_users) | List of users to create. Those users will be created in Keycloak, and used for ArgoCD. | <pre>map(object({<br>    username   = string<br>    password   = string<br>    email      = string<br>    is_admin   = bool<br>    first_name = string<br>    last_name  = string<br>  }))</pre> | n/a | yes |

## Outputs

No outputs.
