# Infrastructure Deployment on Hetzner Cloud with Terragrunt, Kubernetes & ArgoCD

This project leverages multiple Infrastructure-as-Code solutions to provision, configure and maintain a Kubernetes cluster on the Hetzner Cloud platform,.

## Project Structure

The repository is divided into two parts: The infrastructure provisioning and the application deployment. For the initial infrastructure provisioning, Terraform and Terragrunt are used. The relevant files are located in the `terragrunt` directory. The application deployment is handled by ArgoCD, which uses the manifests in the `applications` directory.

## Infrastructure Provisioning

The provisioning is partitioned into two stages, which Terragrunt orchestrates in sequence:

1. **[Foundation](./terragrunt/foundation)**: This stage includes the base infrastructure and the Kubernetes cluster components. It will create Hetzner Cloud instance with an RKE cluster and Keycloak.

1. **[Extensions](./terragrunt/extensions)**: This stage applies additional components into the cluster, like ArgoCD.
