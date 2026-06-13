#!/usr/bin/env bash
# Kustomize KRM exec generator that aggregates per-service authentik
# blueprints into a single ConfigMap that authentik's worker mounts at
# /blueprints/custom.
#
# Discovery rule: applications/<service>/blueprints/*.yaml is collected;
# each file becomes one data key on the ConfigMap, named
# "<service>__<filename>" to keep keys unique across services.
#
# Invoked via a generator config in applications/authentik/kustomization.yaml:
#
#   apiVersion: tibor.sh/v1
#   kind: BlueprintsAggregator
#   metadata:
#     name: blueprints-aggregator
#     annotations:
#       config.kubernetes.io/function: |
#         exec:
#           path: ../_generators/blueprints-aggregator.sh
#
# Kustomize must be invoked with --enable-alpha-plugins --enable-exec.
# In Argo CD that's set via argocd-cm's kustomize.buildOptions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Drain stdin (kustomize sends ResourceList; we don't use input items).
if [ ! -t 0 ]; then cat >/dev/null; fi

# Stable sort order so the rendered ConfigMap is byte-identical across runs.
mapfile -t FILES < <(
  find "${APPS_DIR}" -mindepth 3 -maxdepth 3 -type f \
    -path '*/blueprints/*.yaml' | sort
)

emit_header() {
  cat <<'EOF'
apiVersion: config.kubernetes.io/v1
kind: ResourceList
items:
  - apiVersion: v1
    kind: ConfigMap
    metadata:
      name: authentik-blueprints
      namespace: authentik
      labels:
        app.kubernetes.io/managed-by: kustomize-blueprints-aggregator
EOF
}

emit_header

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "    data: {}"
  exit 0
fi

echo "    data:"
for f in "${FILES[@]}"; do
  rel="${f#${APPS_DIR}/}"
  svc="${rel%%/blueprints/*}"
  base="${rel##*/}"
  # Strip .enc suffix if present
  if [[ "${base}" == *.enc.yaml ]]; then
    key="${svc}__${base%.enc.yaml}"
  else
    key="${svc}__${base}"
  fi
  echo "      ${key}: |"
  # Indent by 8 spaces to nest under the block scalar header.
  if [[ "${f}" == *.enc.yaml ]]; then
    sops -d "${f}" | sed 's/^/        /'
  else
    sed 's/^/        /' "${f}"
  fi
done
