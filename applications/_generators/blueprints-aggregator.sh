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

if [ ! -t 0 ]; then cat >/dev/null; fi

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
  key="${svc}__${base}"
  echo "      ${key}: |"
  sed 's/^/        /' "${f}"
done
