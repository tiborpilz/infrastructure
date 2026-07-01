terraform {
  required_version = ">= 1.7"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.9"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
