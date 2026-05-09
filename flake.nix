{
  description = "Hetzner Kubernetes platform infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Lets shell.nix delegate to this flake's devShell so vanilla
    # direnv (without nix-direnv) works via `use nix`.
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # apricote/hcloud-upload-image — not in nixpkgs as of 2026-05.
        # Pinned here so the dev shell has it without operator-side `go install`.
        hcloud-upload-image = pkgs.buildGoModule rec {
          pname = "hcloud-upload-image";
          version = "1.3.0";

          src = pkgs.fetchFromGitHub {
            owner = "apricote";
            repo = "hcloud-upload-image";
            rev = "v${version}";
            hash = "sha256-1u9tpzciYjB/EgBI81pg9w0kez7hHZON7+AHvfKW7k0=";
          };

          vendorHash = "sha256-IdOAUBPg0CEuHd2rdc7jOlw0XtnAhr3PVPJbnFs2+x4=";

          # Repo uses a Go workspace (go.work). Disable workspace mode so
          # buildGoModule can vendor cleanly.
          env.GOWORK = "off";

          # main.go lives at the repo root; restrict build to it
          # (hcloudimages/ is a separate Go module).
          subPackages = [ "." ];

          meta = with pkgs.lib; {
            description = "Upload arbitrary disk images to Hetzner Cloud as snapshots";
            homepage = "https://github.com/apricote/hcloud-upload-image";
            license = licenses.mit;
            mainProgram = "hcloud-upload-image";
          };
        };
      in
      {
        packages.hcloud-upload-image = hcloud-upload-image;

        devShells.default = pkgs.mkShell {
          packages = (with pkgs; [
            # Terraform / Terragrunt
            terragrunt
            opentofu

            # Hetzner Cloud
            hcloud

            # Talos / Kubernetes
            talosctl
            kubectl
            kubernetes-helm

            # GitOps
            argocd

            # Secrets
            sops
            age

            # Misc
            xz
            curl
            jq
            go
          ]) ++ [
            hcloud-upload-image
          ];

          shellHook = ''
            REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
            export KUBECONFIG="$REPO_ROOT/.kube/hcloud-poc.kubeconfig"
            export TALOSCONFIG="$REPO_ROOT/.talos/hcloud-poc.talosconfig"

            echo "infra dev shell ready"
            echo "  terragrunt $(terragrunt --version 2>/dev/null | head -1)"
            echo "  opentofu   $(tofu --version 2>/dev/null | head -1)"
            echo "  talosctl   $(talosctl version --client --short 2>/dev/null | head -1 || echo)"
            echo
            echo "  KUBECONFIG  = $KUBECONFIG"
            echo "  TALOSCONFIG = $TALOSCONFIG"
          '';
        };
      });
}
