{ config, lib, pkgs, inputs, ... }:

let
  # Source tree of github:tiborpilz/nixos (the flake input). Its home modules are
  # imported by absolute store path; their relative `import ../../../lib` resolves
  # within the same store tree.
  nixcfg = inputs.nixcfg;
in
{
  imports = [
    # Sets xdg.enable = true, which exports XDG_CONFIG_HOME/XDG_CACHE_HOME/... as
    # session variables. zsh.nix and tmux.nix read those at eval time.
    "${nixcfg}/home/modules/xdg.nix"

    # The actual neovim/zsh/tmux configuration, reused verbatim.
    "${nixcfg}/home/modules/editors/neovim.nix"
    "${nixcfg}/home/modules/shell/zsh.nix"
    "${nixcfg}/home/modules/shell/tmux.nix"
  ];

  # Run as root inside the nixos/nix workspace image (single-user Nix). The
  # neovim/zsh modules mkOutOfStoreSymlink into ${homeDirectory}/Code/nixos, so
  # the startup script clones the repo to /root/Code/nixos.
  home.username = "root";
  home.homeDirectory = "/root";
  home.stateVersion = "23.11";

  home.sessionVariables.EDITOR = "nvim";

  modules.editors.neovim.enable = true;
  modules.shell.zsh.enable = true;
  modules.shell.tmux.enable = true;

  programs.home-manager.enable = true;
}
