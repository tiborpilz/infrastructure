# Kubernetes Applications Configuration

This directory defines Kubernetes applications using ArgoCD, following the 'app-of-apps' pattern. The `kustomization.yaml` file at the top level lists the applications to be deployed. Inside each subdirectory is a dedicated `application.yaml` file for an individual application, outlining its configuration and deployment parameters in accordance with ArgoCD.
