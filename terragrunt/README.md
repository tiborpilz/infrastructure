# Terragrunt Configuration

This directory contains the Terragrunt configuration for the infrastructure, organized as follows:

1. [foundation](./foundation) - This stage includes the base infrastructure and the Kubernetes cluster components. It features Hetzner Cloud instances, external IPs, DNS records, and the Kubernetes cluster setup. The cluster is based on an RKE cluster integrated into the foundation infrastructure, along with critical Kubernetes resources such as `cert-manager` for managing certificates, `metallb` for load balancing, and `keycloak` for authentication.

2. [extensions](./extensions) - This stage encompasses additional infrastructure tools that enhance capabilities. It includes `argocd` for streamlined application deployment within the cluster, integrating with `keycloak`, and `rancher` for management of the Kubernetes cluster.
