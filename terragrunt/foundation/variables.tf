variable "secrets" {
  type        = map(string)
  description = "Encrypted secrets"
}

variable "nodes" {
  description = "Node configuration"
}

variable "versions" {
  type        = map(string)
  description = "Versions for the various components to use"
}

variable "domain" {
  type        = string
  description = "The domain to use"
}

variable "email" {
  type        = string
  description = "The email to use for letsencrypt"
}

variable "gitlab_infrastructure_project_id" {
  type        = string
  description = "The id of the infrastructure project in gitlab"
}
