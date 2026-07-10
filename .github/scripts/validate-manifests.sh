#!/usr/bin/env bash
# Render every kustomization with `kustomize build` and schema-validate the
# output with kubeconform.
#
# Apps whose manifests are produced by sops/ksops exec generators need the age
# key, which CI doesn't have, so they are skipped here and validated at Argo
# sync time instead. They're detected dynamically — a `generators:` block, or a
# parent kustomization that recurses into one — rather than hard-coded, so a new
# secret-backed app can't silently slip through the gate as "passing".
set -uo pipefail

ROOT="${1:-applications}"
# Allow a multi-word launcher (e.g. KUSTOMIZE="kubectl kustomize") for local runs.
KUSTOMIZE="${KUSTOMIZE:-kustomize}"
K8S_VERSION="${K8S_VERSION:-1.31.0}"

# kustomize's wording when an exec/external plugin is referenced without
# --enable-alpha-plugins --enable-exec (covers both ksops and the authentik
# BlueprintsAggregator generator, and any parent that includes them).
exec_sig='external plugin|exec plugin|alpha.?plugins?|enable-exec|ksops'

declare -a ok=() skipped=()
rc=0
err="$(mktemp)"
trap 'rm -f "$err"' EXIT

while IFS= read -r kfile; do
  dir="$(dirname "$kfile")"

  # kind: Component isn't standalone-renderable; it's validated through whichever
  # overlay lists it under `components:`.
  if grep -qE '^kind:[[:space:]]+Component' "$kfile"; then
    continue
  fi

  if ! render="$($KUSTOMIZE build "$dir" 2>"$err")"; then
    if grep -qiE "$exec_sig" "$err"; then
      skipped+=("$dir")
      continue
    fi
    echo "::error title=kustomize build failed::$dir"
    sed 's/^/    /' "$err"
    rc=1
    continue
  fi

  if printf '%s\n' "$render" | kubeconform \
      -strict -ignore-missing-schemas \
      -kubernetes-version "$K8S_VERSION" \
      -summary -output text; then
    ok+=("$dir")
  else
    echo "::error title=kubeconform failed::$dir"
    rc=1
  fi
done < <(find "$ROOT" -name kustomization.yaml | sort)

echo
echo "validated ${#ok[@]} kustomization(s)."
if ((${#skipped[@]})); then
  echo "skipped ${#skipped[@]} (secret-backed, validated at Argo sync time):"
  printf '  - %s\n' "${skipped[@]}"
fi
exit "$rc"
