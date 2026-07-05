# `nix-devbox` Coder template

Provisions a Kubernetes workspace that reproduces the neovim/zsh/tmux setup from
[`github:tiborpilz/nixos`](https://github.com/tiborpilz/nixos) via home-manager.

## What it does

- Runs the [`nixos/nix`](https://hub.docker.com/r/nixos/nix) image as root (single-user
  Nix) with a persistent PVC mounted at `/root`.
- On start (`coder_agent.startup_script`):
  1. clones `tiborpilz/nixos` to `~/Code/nixos` (the neovim/zsh modules
     `mkOutOfStoreSymlink` their config out of that path);
  2. writes the embedded `flake.nix` + `home.nix` (materialized from this template via
     base64, so the workspace needs no access to the private infra repo);
  3. `nix build`s and activates `homeConfigurations.root`, which imports the real
     `home/modules/{editors/neovim,shell/zsh,shell/tmux}.nix` from the dotfiles repo.
- `zsh` is the login shell (`SHELL`/`ZDOTDIR` set on the agent); `nvim` (lazy.nvim) and
  `tmux` (with the user's status bar) come up configured. Plugin managers (antigen,
  lazy.nvim) self-bootstrap on first run.

## Pushing the template

Templates are not GitOps-synced; push them with the Coder CLI:

```sh
coder login https://coder.tibor.sh
coder templates push nix-devbox -d applications/services/coder/templates/nix-devbox
```

Then create a workspace from the `nix-devbox` template in the Coder UI.

## Notes / tuning

- **Cold starts:** `/nix` is not persisted (only `/root` is), so the first build after a
  restart re-fetches the closure. The user's binary caches (`tiborpilz.cachix.org`,
  `nix-community`) are added as extra substituters to keep this fast. To persist the Nix
  store across restarts, add a second PVC and an init-copy of the image's `/nix`.
- **Validate the home-manager closure before pushing** (it can't be built in CI that lacks
  Nix):
  ```sh
  nix build ./#homeConfigurations.root.activationPackage
  ```
- Parameters: `cpu`, `memory`, `home_disk_size` (set at workspace creation).
