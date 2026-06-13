{
  description = "Terraform on Hetzner Cloud";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    robinovitch61 = {
      url = "github:robinovitch61/nur-packages";
    };
  };

  outputs = { nixpkgs, flake-utils, robinovitch61, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          packages = (with pkgs; [
            terragrunt
            opentofu

            hcloud
            pkgs.hcloud-upload-image

            talosctl
            kubectl
            kubernetes-helm

            argocd

            velero

            kdash
            k9s
            ktop

            robinovitch61.legacyPackages.${system}.kl

            sops
            age
            ssh-to-age
            jq
          ]);

          shellHook = ''
            REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
            export KUBECONFIG="$REPO_ROOT/.kube/hcloud-poc.kubeconfig"
            export TALOSCONFIG="$REPO_ROOT/.talos/hcloud-poc.talosconfig"
          '';
        };
      });
}
