#!/usr/bin/env bash
# Writes .kube/ and .talos/ config files from terraform state.
#
# A fresh checkout has neither file, and the steps that need them run in the
# same apply that creates them. Both are already recorded as outputs, so
# reading state breaks the cycle without planning, locking or touching the
# cluster.
#
# An `apply -target` cannot do this job. The local provider only notices a
# missing file during refresh, so `-refresh=false` writes nothing, and a
# refreshing apply has to walk the whole graph the file hangs off.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root/terragrunt/cluster"

cluster_name="$(terragrunt output -raw cluster_name)"

kubeconfig="$repo_root/.kube/${cluster_name}.kubeconfig"
talosconfig="$repo_root/.talos/${cluster_name}.talosconfig"

mkdir -p "$(dirname "$kubeconfig")" "$(dirname "$talosconfig")"

for target in "$kubeconfig" "$talosconfig"; do
  # Create with the final permissions rather than tightening afterwards, so the
  # secret is never briefly world-readable.
  install -m 0600 /dev/null "$target"
done

terragrunt output -raw kubeconfig >"$kubeconfig"
terragrunt output -raw talosconfig >"$talosconfig"

echo "wrote $kubeconfig"
echo "wrote $talosconfig"
echo "run terragrunt plan next"
