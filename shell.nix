# Delegates to the flake's devShell so this works with vanilla direnv
# (`use nix`) when nix-direnv (`use flake`) is not installed.
#
# Single source of truth is flake.nix.

(import
  (
    let lock = builtins.fromJSON (builtins.readFile ./flake.lock); in
    fetchTarball {
      url = "https://github.com/edolstra/flake-compat/archive/${lock.nodes.flake-compat.locked.rev}.tar.gz";
      sha256 = lock.nodes.flake-compat.locked.narHash;
    }
  )
  { src = ./.; }
).shellNix
