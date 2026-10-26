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

    tangled = {
      url = "git+https://tangled.org/tangled.org/core";
    };
  };

  outputs = { nixpkgs, flake-utils, robinovitch61, tangled, ... }:
    let
      spindleVm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit tangled; };
        modules = [
          tangled.nixosModules.spindle
          ./nix/spindle-vm.nix
        ];
      };
    in
    {
      nixosConfigurations.spindle-vm = spindleVm;

      # KubeVirt containerDisk: the qcow2 must sit under /disk in the image.
      packages.x86_64-linux.spindle-vm-containerdisk =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          image = spindleVm.config.system.build.image;
        in
        pkgs.dockerTools.buildImage {
          name = "spindle-vm";
          copyToRoot = pkgs.runCommand "spindle-vm-disk" { } ''
            mkdir -p $out/disk
            cp ${image}/${spindleVm.config.image.fileName} $out/disk/
          '';
        };
    } // flake-utils.lib.eachDefaultSystem (system:
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
            kustomize
            kustomize-sops
            kubernetes-helm

            argocd

            velero

            k9s
            kubectl-ktop

            robinovitch61.legacyPackages.${system}.kl

            skopeo
            kubevirt

            sops
            age
            ssh-to-age
            jq
            gitleaks
          ]);

          shellHook = ''
            REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
            export KUBECONFIG="$REPO_ROOT/.kube/hcloud-poc.kubeconfig"
            export TALOSCONFIG="$REPO_ROOT/.talos/hcloud-poc.talosconfig"

            # Enable kustomize-sops plugin for SOPS decryption during kustomize build
            export KUSTOMIZE_PLUGIN_HOME="${pkgs.kustomize-sops}/lib"
          '';
        };
      });
}
