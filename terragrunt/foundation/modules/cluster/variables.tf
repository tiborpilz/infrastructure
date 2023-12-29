variable "nodes" {
  type    = map(object({
    name          = string
    ipv4_address  = string
    labels        = map(string)
  }))
  description = "Hetzner Cloud nodes"
}

variable "ssh_key" {
  type    = map(string)
  description = "SSH key to use for the k8s nodes."
}

variable "versions" {
  type = map(string)
  description = "Versions for the various components to use"
}

variable "gitlab_infrastructure_project_id" {
  description = "The id of the infrastructure project in gitlab"
}

variable "email" {
  type        = string
  description = "The email to use for letsencrypt"
}

variable "domain" {
  type        = string
  description = "The domain to use"
}

variable "hcloud_token" {
  type        = string
  description = "The hcloud token to use"
}

variable "gitlab_token" {
  type        = string
  description = "The gitlab token to use"
}

variable "ingress_ips" {
  type    = list(string)
  default = []
  description = "List of ingress IPs to use for metallb."
}

variable "keycloak_admin_password" {
  type        = string
  description = "The keycloak admin password to use"
}
