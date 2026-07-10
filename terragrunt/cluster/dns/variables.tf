variable "domain" {
  description = "Second-level domain to use for the cluster."
  type        = string
}

variable "zone" {
  description = "Cloudflare zone holding the records. Defaults to var.domain; set it when the domain is a subdomain of the zone."
  type        = string
  default     = null
}

variable "lb_ipv4" {
  description = "IPv4 of the ingress floating IP. Used for the wildcard DNS record."
  type        = string
}

variable "nodes" {
  description = "Maps of control-plane and worker nodes' names to their public IPv4 addresses."
  type = object({
    control_plane = map(object({
      public_ipv4 = string
    }))
    workers = map(object({
      public_ipv4 = string
    }))
  })
}
