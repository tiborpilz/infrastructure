#!/usr/bin/env bash
# Builds the spindle VM containerDisk, pushes it to Harbor and pins the
# VirtualMachine to the pushed digest.
#
# Requires `skopeo login harbor.tibor.sh` beforehand.
set -euo pipefail

repo="${REPO:-harbor.tibor.sh/library/spindle-vm}"

repo_root="$(git rev-parse --show-toplevel)"
manifest="$repo_root/applications/services/tangled/spindle/virtualmachine.yaml"

for cmd in nix skopeo; do
  command -v "$cmd" >/dev/null || { echo "missing required tool: $cmd (run \`nix develop\` or \`direnv allow\`)" >&2; exit 1; }
done

archive="$(nix build "$repo_root#spindle-vm-containerdisk" --no-link --print-out-paths)"
tag="$(basename "$archive" | cut -c1-12)"

digest_file="$(mktemp)"
trap 'rm -f "$digest_file"' EXIT

skopeo copy --digestfile "$digest_file" "docker-archive:$archive" "docker://$repo:$tag"
digest="$(cat "$digest_file")"

sed -i -E "s|image: $repo@sha256:[0-9a-f]+|image: $repo@$digest|" "$manifest"
echo "pushed $repo:$tag ($digest), updated $manifest"
