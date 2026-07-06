terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

# The Coder server runs inside the cluster (see applications/services/coder), so
# the provisioner authenticates via its in-cluster service account. Flip
# use_kubeconfig to true only if you ever run Coder outside the cluster.
variable "use_kubeconfig" {
  type        = bool
  default     = false
  description = "Use the host ~/.kube/config (true when the Coder host is outside the cluster)."
}

variable "namespace" {
  type        = string
  default     = "coder"
  description = "Kubernetes namespace workspaces are created in."
}

provider "coder" {}

provider "kubernetes" {
  config_path = var.use_kubeconfig == true ? "~/.kube/config" : null
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU"
  description  = "vCPU cores"
  type         = "number"
  default      = 2
  icon         = "/icon/memory.svg"
  mutable      = true
  order        = 1
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory"
  description  = "GiB of RAM"
  type         = "number"
  default      = 4
  icon         = "/icon/memory.svg"
  mutable      = true
  order        = 2
}

data "coder_parameter" "home_disk_size" {
  name         = "home_disk_size"
  display_name = "Home disk size"
  description  = "GiB of persistent storage for /root (home directory). Nix store is not persisted."
  type         = "number"
  default      = 20
  icon         = "/icon/folder.svg"
  mutable      = false
  order        = 3
  validation {
    min = 10
  }
}

locals {
  # Run as root so single-user Nix (nixos/nix image) can build into /nix.
  # The reused home-manager modules symlink config out of $HOME/Code/nixos, so
  # the repo is cloned there and HOME/home dir are kept consistent at /root.
  home_dir = "/root"

  # The embedded home-manager flake is read from disk and written into the
  # workspace by the startup script. file() returns raw content, so the Nix
  # ${...} interpolations inside these files are preserved verbatim.
  flake_nix = file("${path.module}/flake.nix")
  home_nix  = file("${path.module}/home.nix")
}

resource "coder_agent" "main" {
  os                      = "linux"
  arch                    = "amd64"
  startup_script_behavior = "non-blocking"

  env = {
    HOME            = local.home_dir
    USER            = "root"
    XDG_CONFIG_HOME = "${local.home_dir}/.config"
    XDG_CACHE_HOME  = "${local.home_dir}/.cache"
    XDG_DATA_HOME   = "${local.home_dir}/.local/share"
    XDG_STATE_HOME  = "${local.home_dir}/.local/state"
    # Bootstrap ZDOTDIR into the environment so interactive zsh reads the
    # home-manager-managed rc at $XDG_CONFIG_HOME/zsh before anything else.
    ZDOTDIR = "${local.home_dir}/.config/zsh"
    SHELL   = "${local.home_dir}/.nix-profile/bin/zsh"
    EDITOR  = "nvim"
  }

  # Enable flakes and prefer the user's binary caches so the neovim/zsh/tmux
  # closure is fetched instead of rebuilt.
  startup_script = <<-EOT
    set -eux

    export HOME=${local.home_dir}
    export USER=root
    export NIX_CONFIG="experimental-features = nix-command flakes"
    HM_DIR="$HOME/.config/coder-home"
    mkdir -p "$HOME/Code" "$HM_DIR"

    # 1. Clone the dotfiles repo. The reused neovim/zsh home-manager modules use
    #    mkOutOfStoreSymlink into $HOME/Code/nixos/home/config, so the live
    #    config files must exist there.
    if [ ! -d "$HOME/Code/nixos/.git" ]; then
      git clone --depth 1 https://github.com/tiborpilz/nixos "$HOME/Code/nixos"
    else
      git -C "$HOME/Code/nixos" pull --ff-only || true
    fi

    # 2. Materialize the embedded home-manager flake (written verbatim from the
    #    template so the workspace needs no access to the private infra repo).
    #    base64 avoids any Terraform/shell interpolation of the Nix source.
    printf '%s' '${base64encode(local.flake_nix)}' | base64 -d > "$HM_DIR/flake.nix"
    printf '%s' '${base64encode(local.home_nix)}'  | base64 -d > "$HM_DIR/home.nix"

    # 3. Build and activate the neovim/zsh/tmux home-manager generation.
    nix build "$HM_DIR#homeConfigurations.root.activationPackage" \
      --extra-substituters "https://tiborpilz.cachix.org https://nix-community.cachix.org" \
      --extra-trusted-public-keys "tiborpilz.cachix.org-1:KyBjAXY8eblxntQ+OG13IjT+M222VxT+25yw1lqnQS4= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" \
      -o "$HOME/.hm-activate"
    "$HOME/.hm-activate/activate"
  EOT

  metadata {
    display_name = "CPU Usage"
    key          = "cpu"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }
  metadata {
    display_name = "RAM Usage"
    key          = "mem"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }
  metadata {
    display_name = "Home Disk"
    key          = "disk"
    script       = "coder stat disk --path $HOME"
    interval     = 60
    timeout      = 1
  }
}

resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${lower(data.coder_workspace.me.id)}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-workspace-${lower(data.coder_workspace.me.id)}"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
  }
  wait_until_bound = false
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "ceph-block"
    resources {
      requests = {
        storage = "${data.coder_parameter.home_disk_size.value}Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "main" {
  count            = data.coder_workspace.me.start_count
  depends_on       = [kubernetes_persistent_volume_claim.home]
  wait_for_rollout = false

  metadata {
    name      = "coder-${lower(data.coder_workspace.me.id)}"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-workspace-${lower(data.coder_workspace.me.id)}"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        "com.coder.workspace.id" = data.coder_workspace.me.id
      }
    }
    strategy {
      type = "Recreate"
    }
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "coder-workspace"
          "com.coder.workspace.id" = data.coder_workspace.me.id
        }
      }
      spec {
        security_context {
          run_as_user = 0
          fs_group    = 0
        }

        container {
          name    = "dev"
          image   = "nixos/nix:2.24.9"
          command = ["sh", "-c", coder_agent.main.init_script]

          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }

          # coder_agent.env only reaches the agent's managed sessions, not the
          # agent process itself (the container command). Point its cache at the
          # writable PVC here, or it defaults to $HOME/.cache (/home/coder/.cache)
          # and crashes: "create cache directory: ... read-only file system".
          env {
            name  = "HOME"
            value = local.home_dir
          }
          env {
            name  = "XDG_CACHE_HOME"
            value = "${local.home_dir}/.cache"
          }

          resources {
            requests = {
              "cpu"    = "250m"
              "memory" = "512Mi"
            }
            limits = {
              "cpu"    = "${data.coder_parameter.cpu.value}"
              "memory" = "${data.coder_parameter.memory.value}Gi"
            }
          }

          volume_mount {
            mount_path = local.home_dir
            name       = "home"
            read_only  = false
          }
        }

        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
            read_only  = false
          }
        }
      }
    }
  }
}
