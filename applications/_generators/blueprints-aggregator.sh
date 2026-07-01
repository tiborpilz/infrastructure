#!/usr/bin/env bash
# Requires kustomize --enable-alpha-plugins --enable-exec (set via argocd-cm kustomize.buildOptions).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [ ! -t 0 ]; then cat >/dev/null; fi

mapfile -t FILES < <(
  find "${APPS_DIR}" -mindepth 3 -type f \
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
  svc="$(basename "${rel%%/blueprints/*}")"
  base="${rel##*/}"
  if [[ "${base}" == *.enc.yaml ]]; then
    key="${svc}__${base%.enc.yaml}"
  else
    key="${svc}__${base}"
  fi
  echo "      ${key}: |"
  if [[ "${f}" == *.enc.yaml ]]; then
    sops -d "${f}" | sed 's/^/        /'
  else
    sed 's/^/        /' "${f}"
  fi
done
