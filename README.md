# Infrastructure Deployment on Hetzner Cloud with Terragrunt, Kubernetes & ArgoCD

This project leverages multiple Infrastructure-as-Code solutions to provision, configure and maintain a Kubernetes cluster on the Hetzner Cloud platform. It is entirely declarative, using Terraform, Terragrunt and Kubernetes to define the infrastructure as well as the applications that run on it. The cluster is then managed by Rancher2 and ArgoCD, which is responsible for the deployment of applications and updates.

## Project Structure

The repository can be divided into two parts: The infrastructure provisioning and the application deployment. For the initial infrastructure provisioning, Terraform and Terragrunt are used. The relevant files are located in the `terragrunt` directory. The application deployment is handled by ArgoCD, which uses the manifests in the `applications` directory.

## Infrastructure Provisioning

The provisioning is partitioned into two stages, which Terragrunt orchestrates in sequence:

1. **[Foundation](./terragrunt/foundation)**: This stage includes the base infrastructure and the Kubernetes cluster components. It features Hetzner Cloud instances, external IPs, DNS records, and the Kubernetes cluster setup. The cluster is based on an RKE cluster integrated into the foundation infrastructure, along with critical Kubernetes resources such as `cert-manager` for managing certificates, `metallb` for load balancing, and `keycloak` for authentication.

1. **[Extensions](./terragrunt/extensions)**: This stage encompasses additional infrastructure tools that enhance capabilities. It includes `argocd` for streamlined application deployment within the cluster, integrating with `keycloak`, and `rancher` for management of the Kubernetes cluster.

### Why Terragrunt?

When you're using Terraform for infrastructure as code, it does a great job. But, it does have some limitations when dealing with complex projects that have interdependent resources. For example, in a project where we're setting up a Kubernetes cluster and then deploying resources into that same cluster, there's a catch. To query the state of Kubernetes resources (like a Helm release), the Kubernetes API needs to be present and able to respond. Because Terraform needs to understand the state of a resource before applying it, it can trip up when the Kubernetes cluster isn't there from the get-go.

That's where Terragrunt comes in handy. It lets us define inter-project dependencies, lining up our Terraform projects in the right order. This way, the results of one project can be used as inputs for the next one. In scenarios like these, where the same project deploys a Kubernetes cluster and then deploys resources into it, Terragrunt is a really useful tool.

## Overview of Technologies used

- [Terraform](https://www.terraform.io/)
- [Terragrunt](https://terragrunt.gruntwork.io/)
- [Hetzner Cloud](https://www.hetzner.com/cloud)
- [Hetzner Cloud Terraform Provider](https://github.com/hetznercloud/terraform-provider-hcloud)
- [Kubernetes](https://kubernetes.io/)
- [ArgoCD](https://argoproj.github.io/argo-cd/)
- [Keycloak](https://www.keycloak.org/)
- [Keycloak Operator](https://operatorhub.io/operator/keycloak-operator)
- [Oauth Proxy 2](https://github.com/oauth2-proxy/oauth2-proxy)
- [RKE](https://rancher.com/products/rke/)
- [Rancher2](https://rancher.com/)

## About The Technologies

### Terraform

Terraform is a tool for managing infrastructure as code. It provides a consistent CLI workflow for managing cloud service. Terraform codifies APIs into declarative configuration files, which can be shared among team members, treated as code, and edited, reviewed, and versioned.

### Terragrunt

Terragrunt is a thin wrapper around Terraform that provides extra tooling for working with multiple Terraform modules. It manages and orchestrates interdependent Terraform projects to ensure correct and efficient deployment.

### Kubernetes

Kubernetes is an open-source container orchestration system for automating software deployment, scaling, and management. Although complex, it's a powerful tool that abstracts away a lot of the complexity of networking and application deployment. Setting up a Kubernetes cluster, especially a production-ready one with high availability is a daunting task, which is why it's a perfect fit for a project like this.

### RKE - Rancher Kubernetes Engine

RKE is a CNCF-certified Kubernetes distribution that runs entirely within Docker containers. It simplifies Kubernetes deployment and is used in this project for setting up the Kubernetes cluster.

### Hetzner Cloud

Hetzner Cloud provides reliable and cost-effective cloud servers with excellent tooling.

### Hetzner Cloud Terraform Provider

The Hetzner Cloud Terraform Provider is an extension for Terraform that allows it to interact with Hetzner Cloud's resources, making the integration of Hetzner Cloud into this project possible.

### ArgoCD

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It facilitates the automated deployment of applications, following the principle of infrastructure as code, which will enable us to deploy and update applications in a declarative manner, even if they are not defined in this project.

### Keycloak

Keycloak is an open-source software product that provides identity and access management. In this project, Keycloak handles user authentication and management, providing an extra layer of security.

### Keycloak Operator / Keycloak Realm Operator

The Keycloak Operator is a Kubernetes Operator that enables declarative configuration of Keycloak. Currently, it's undergoing a rewrite, so to still keep the set up declarative, we're using an additional operator, which is a fork of the legacy Keycloak Operator.

### Oauth Proxy 2

OAuth2 Proxy is a reverse proxy that can be used in conjunction with the Nginx-Ingress controller and Keycloak to enable SSO access for applications that don't support it natively.

### Rancher2

Rancher2 is an open-source software platform that can be used to manage Kubernetes clusters. It provides a user interface for monitoring and managing the cluster, but most importantly, it enables `kubectl` access which is tied to user accounts, which in turn are managed by Keycloak.
