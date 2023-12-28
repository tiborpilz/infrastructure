# Terragrunt Configuration

This directory contains the Terragrunt configuration for the infrastructure. It is split into three parts:

1. [foundation](./foundation) - The base infrastructure that all other infrastructure is built on top of. This includes Hetzner Cloud instances, external IPs and DNS records.
2. [cluster](./cluster) - The Kubernetes cluster. This installs a RKE cluster on top of the foundation infrastructure - including a few base Kubernetes resources, like `cert-manager` for fetching certificates, `metallb` for load balancing and `keycloak` for authentication.
3. [extensions](./extensions) - Additional infrastructure that is not required for the cluster to function, but is useful for development. This includes `argocd` for deploying applications to the cluster (complete with a `keycloak` integration), and `rancher` for managing the cluster.
