# Foundation

This module creates the foundation for a Kubernetes cluster.
Based on a node config, it will create Hetzner Cloud servers and connect external IPs to them.
Then, it will initialize the cluster using rke and install argocd, keycloak, cert-manager, ingress-nginx and metallb.

## Requirements

No requirements.

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cloudflare"></a> [cloudflare](#module\_cloudflare) | ./modules/cloudflare | n/a |
| <a name="module_cluster"></a> [cluster](#module\_cluster) | ./modules/cluster | n/a |
| <a name="module_hetzner"></a> [hetzner](#module\_hetzner) | ./modules/hetzner | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_domain"></a> [domain](#input\_domain) | The domain to use | `string` | n/a | yes |
| <a name="input_email"></a> [email](#input\_email) | The email to use for letsencrypt | `string` | n/a | yes |
| <a name="input_gitlab_infrastructure_project_id"></a> [gitlab\_infrastructure\_project\_id](#input\_gitlab\_infrastructure\_project\_id) | The id of the infrastructure project in gitlab | `string` | n/a | yes |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Node configuration | `any` | n/a | yes |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | Encrypted secrets | `map(string)` | `{}` | no |
| <a name="input_versions"></a> [versions](#input\_versions) | Versions for the various components to use | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_connection"></a> [cluster\_connection](#output\_cluster\_connection) | The cluster connection |
| <a name="output_domain"></a> [domain](#output\_domain) | n/a |
| <a name="output_ingress_ips"></a> [ingress\_ips](#output\_ingress\_ips) | List of ingress IPs. |
| <a name="output_kube_config_yaml"></a> [kube\_config\_yaml](#output\_kube\_config\_yaml) | The generated kube config yaml |
| <a name="output_nodes"></a> [nodes](#output\_nodes) | Hetzner Cloud VMs with their respective roles. |
| <a name="output_ssh_key"></a> [ssh\_key](#output\_ssh\_key) | The generated SSH key for connecting to the nodes. |
