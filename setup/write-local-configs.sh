#!/usr/bin/env bash
# Writes .kube/ and .talos/ config files from terraform state.
#
# A fresh checkout has neither file, and the steps that need them run in the
# same apply that creates them. Both are derived from state that already
# exists, so a targeted apply breaks the cycle without touching the cluster.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)/terragrunt/cluster"

terragrunt apply -refresh=false -auto-approve \
  -target=module.talos.local_sensitive_file.kubeconfig \
  -target=module.talos.local_sensitive_file.talosconfig

echo "wrote kubeconfig and talosconfig, run terragrunt plan next"
