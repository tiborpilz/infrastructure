variable "nodes" {
  type    = map(object({
    name          = string
    ipv4_address  = string
  }))
  description = "Hetzner Cloud nodes"
}

variable "floating_ip" {
  description = "The floating ip to use"
}

variable "domain" {
  type        = string
  description = "The domain to use"
}

variable "cloudflare_api_token" {
  type        = string
  description = "The cloudflare api token to use"
}
