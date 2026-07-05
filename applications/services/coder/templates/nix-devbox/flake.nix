{
  description = "Coder workspace home-manager env: neovim/zsh/tmux from tiborpilz/nixos";

  inputs = {
    # Match the channels the dotfiles repo targets so the reused modules build
    # against the pkgs set they expect.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # The dotfiles repo. Its home/modules/{editors/neovim,shell/zsh,shell/tmux}.nix
    # are imported directly by home.nix.
    nixcfg.url = "github:tiborpilz/nixos";
  };

  outputs =
    { self, nixpkgs, nixpkgs-unstable, home-manager, nixcfg, ... } @ inputs:
    let
      system = "x86_64-linux";

      # neovim.nix references pkgs.unstable.*, so expose an `unstable` overlay
      # exactly like the dotfiles flake does.
      overlay = final: prev: {
        unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      };

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ overlay ];
      };
    in
    {
      homeConfigurations.root = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        # The reused modules take an `inputs` arg (only to import the repo's lib
        # helpers); pass the flake inputs through so it resolves.
        extraSpecialArgs = { inherit inputs; };
        modules = [ ./home.nix ];
      };
    };
}
