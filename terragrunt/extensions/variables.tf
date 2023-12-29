variable "secrets" {
  type        = map(string)
  description = "Encrypted secrets"
}

variable "cluster_connection" {
  type        = map(string)
  description = "The cluster connection to use"
}

variable "kube_config_yaml" {
  type        = string
  description = "The kube config yaml to use"
}

variable "domain" {
  type        = string
  description = "The domain to use"
}

variable "email" {
  type        = string
  description = "The email used for letsencrypt"
}

variable "rancher_version" {
  type        = string
  description = "The rancher (helm chart) version to use"
}

variable "argocd_version" {
  type        = string
  description = "The argocd (helm chart) version to use"
}

variable "users" {
  type = map(object({
    username   = string
    password   = string
    email      = string
    is_admin   = bool
    first_name = string
    last_name  = string
  }))
  description = "List of users to create. Those users will be created in Keycloak, and used for ArgoCD."
}

variable "gitlab_infrastructure_project_id" {
  description = "The id of the infrastructure project in gitlab"
}
