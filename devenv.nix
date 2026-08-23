{ pkgs, inputs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;

  kl = inputs.robinovitch61.legacyPackages.${system}.kl;
  pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${system};
in
{
  packages = [
    pkgs.terragrunt
    pkgs.opentofu

    pkgs.hcloud
    pkgs-unstable.hcloud-upload-image

    pkgs.talosctl
    pkgs.kubectl
    pkgs.kubernetes-helm

    pkgs.argocd

    pkgs.velero

    pkgs.k9s
    pkgs.ktop

    kl

    pkgs.sops
    pkgs.age
    pkgs.gitleaks
    pkgs.ssh-to-age
    pkgs.jq

    pkgs.bash-completion
  ];

  enterShell = ''
    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

    export KUBECONFIG="$REPO_ROOT/.kube/hcloud-poc.kubeconfig"
    export TALOSCONFIG="$REPO_ROOT/.talos/hcloud-poc.talosconfig"

    # Secret scanning on push.
    if [ -d "$REPO_ROOT/setup/hooks" ]; then
      git config core.hooksPath setup/hooks
    fi

    COMPLETION_DIR="$REPO_ROOT/.devenv/state/completions"
    BASH_COMPLETION_DIR="$COMPLETION_DIR/bash"
    ZSH_COMPLETION_DIR="$COMPLETION_DIR/zsh"
    FISH_COMPLETION_DIR="$COMPLETION_DIR/fish"

    mkdir -p "$BASH_COMPLETION_DIR" "$ZSH_COMPLETION_DIR" "$FISH_COMPLETION_DIR"

    gen_completion() {
      local cmd="$1"
      local shell="$2"
      local out="$3"

      if command -v "$cmd" >/dev/null 2>&1 && [ ! -s "$out" ]; then
        "$cmd" completion "$shell" > "$out" 2>/dev/null || rm -f "$out"
      fi
    }

    for cmd in \
      kubectl \
      helm \
      hcloud \
      argocd \
      talosctl \
      terragrunt \
      velero \
      k9s
    do
      gen_completion "$cmd" bash "$BASH_COMPLETION_DIR/$cmd"
      gen_completion "$cmd" zsh  "$ZSH_COMPLETION_DIR/_$cmd"
      gen_completion "$cmd" fish "$FISH_COMPLETION_DIR/$cmd.fish"
    done

    # Bash completions
    if [ -n "''${BASH_VERSION:-}" ]; then
      if [ -f "${pkgs.bash-completion}/share/bash-completion/bash_completion" ]; then
        source "${pkgs.bash-completion}/share/bash-completion/bash_completion"
      fi

      for completion in "$BASH_COMPLETION_DIR"/*; do
        [ -f "$completion" ] && source "$completion"
      done
    fi

    # Zsh completions
    if [ -n "''${ZSH_VERSION:-}" ]; then
      fpath=("$ZSH_COMPLETION_DIR" $fpath)
      autoload -Uz compinit
      compinit
    fi

    # Fish completions
    if [ -n "''${FISH_VERSION:-}" ]; then
      set -q fish_complete_path
      or set -g fish_complete_path

      contains "$FISH_COMPLETION_DIR" $fish_complete_path
      or set -g fish_complete_path "$FISH_COMPLETION_DIR" $fish_complete_path
    fi
  '';

  # Not wired into enterShell: it runs a terragrunt apply, which decrypts sops
  # secrets and reaches the network. Run it by hand on a fresh checkout.
  tasks."infra:local-configs" = {
    description = "Write kubeconfig and talosconfig from terraform state";
    exec = "$DEVENV_ROOT/setup/write-local-configs.sh";
    status = "test -s $DEVENV_ROOT/.kube/hcloud-poc.kubeconfig && test -s $DEVENV_ROOT/.talos/hcloud-poc.talosconfig";
  };
}
