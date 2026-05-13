variable "hcloud_token" {
  description = "Hetzner Cloud API token."
  type        = string
  sensitive   = true
}

variable "name" {
  description = "Server name in Hetzner. Used as the hostname during bootstrap and as the flake host name unless `flake_host` is set."
  type        = string
}

variable "flake_host" {
  description = "Name of the host under `nixosConfigurations.<flake_host>` in the target flake. Defaults to `name`."
  type        = string
  default     = ""
}

variable "flake_uri" {
  description = "Flake reference passed to nixos-anywhere. Example: `path:/Users/tiborpilz/Code/nixos` for local-disk dev, or `git+ssh://git@github.com/tiborpilz/nixos` for upstream."
  type        = string
}

variable "server_type" {
  description = "Hetzner server type. cx22/cpx21 fit most lightweight NixOS workloads; CCX line only if you need dedicated vCPU or nested virt."
  type        = string
}

variable "location" {
  description = "Hetzner location."
  type        = string
  default     = "fsn1"
}

variable "bootstrap_image" {
  description = "OS image used for the initial boot. nixos-anywhere kexecs over it so the choice is cosmetic; debian-12 is small and reliable."
  type        = string
  default     = "debian-12"
}

variable "ssh_key_names" {
  description = "Names of pre-existing `hcloud_ssh_key` resources to attach. The first key is the one nixos-anywhere uses to log in — its private half must be on the machine running terragrunt."
  type        = list(string)
}

variable "labels" {
  description = "Extra Hetzner labels to merge onto the server."
  type        = map(string)
  default     = {}
}

variable "delete_protection" {
  description = "Hetzner delete_protection on the server and its primary IP. Default true because nixos-anywhere is destructive on the boot disk; you don't want an accidental `tofu destroy` to take it out."
  type        = bool
  default     = true
}

variable "firewall_ids" {
  description = "Hetzner firewall IDs to attach to the server. Pass the cluster firewall ID here if you want the same ingress rules."
  type        = list(number)
  default     = []
}

variable "network_id" {
  description = "Hetzner network ID to attach the server to. Leave null to skip private networking."
  type        = number
  default     = null
}

variable "subnet_id" {
  description = "Hetzner subnet ID inside `network_id`. Required when `network_id` is set."
  type        = number
  default     = null
}

variable "private_ipv4" {
  description = "Private IPv4 inside the subnet. Required when `network_id` is set."
  type        = string
  default     = null
}

variable "nixos_anywhere_extra_args" {
  description = "Extra arguments appended to the `nixos-anywhere` invocation. Useful for `--build-on remote` if your laptop can't build the system, or `--phases install,reboot` to skip kexec on re-runs (though triggers_replace already prevents accidental re-runs)."
  type        = list(string)
  default     = []
}
