#!/usr/bin/env bash
# Boots a local Talos cluster ("third machine kind" next to hcloud and
# proxmox) to test node configuration and the bootstrap-installed Kubernetes
# setup without touching any cloud API.
#
# Nodes get the same machine config shape as production: CNI none +
# kube-proxy disabled (Cilium via inline manifests), the production sysctls,
# and the real bootstrap manifests rendered by terragrunt/test/local-vm.
# Deliberate differences, mirroring how the proxmox workers already deviate:
#   - externalCloudProvider stays off (no hcloud CCM to initialize nodes)
#   - kubespan stays off (all VMs share one local bridge)
#   - hcloud CSI/CCM and external-dns manifests are skipped (cloud APIs)
#
# Usage: setup/local-talos-cluster.sh [up|down|status]
#   PROVISIONER=qemu|docker  (default: qemu when Linux with /dev/kvm, else docker)
#   CLUSTER_NAME=local-test  TALOS_VERSION=<from terragrunt/env.hcl>
set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
CMD="${1:-up}"

CLUSTER_NAME="${CLUSTER_NAME:-local-test}"
RENDER_DIR="${REPO_ROOT}/terragrunt/test/local-vm"
OUT_DIR="${RENDER_DIR}/out"
BASE_PATCH="${OUT_DIR}/local-base-patch.yaml"
BOOTSTRAP_PATCH="${OUT_DIR}/local-bootstrap-patch.yaml"
TALOSCONFIG_OUT="${OUT_DIR}/talosconfig"
KUBECONFIG_OUT="${OUT_DIR}/kubeconfig"

TALOS_VERSION="${TALOS_VERSION:-$(grep -oE 'talos_version[[:space:]]*=[[:space:]]*"[0-9.]+"' "${REPO_ROOT}/terragrunt/env.hcl" | grep -oE '[0-9.]+')}"

if [ -z "${PROVISIONER:-}" ]; then
  if [ "$(uname -s)" = "Linux" ] && [ -e /dev/kvm ]; then
    PROVISIONER=qemu
  else
    PROVISIONER=docker
  fi
fi

# The qemu provisioner creates bridges and runs DHCP; it needs root.
SUDO=""
if [ "${PROVISIONER}" = "qemu" ] && [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo -E"
fi

talos() {
  ${SUDO} talosctl --talosconfig "${TALOSCONFIG_OUT}" "$@"
}

render_patches() {
  echo ">>> Rendering bootstrap inline manifests (real module, dummy credentials)"
  tofu -chdir="${RENDER_DIR}" init -input=false >/dev/null
  tofu -chdir="${RENDER_DIR}" apply -auto-approve -input=false

  cat > "${BASE_PATCH}" <<'EOF'
machine:
  sysctls:
    user.max_user_namespaces: "63359"
cluster:
  allowSchedulingOnControlPlanes: true
  network:
    cni:
      name: none
  proxy:
    disabled: true
  discovery:
    enabled: true
EOF
}

up() {
  mkdir -p "${OUT_DIR}"
  render_patches

  echo ">>> Creating Talos ${TALOS_VERSION} cluster '${CLUSTER_NAME}' (provisioner: ${PROVISIONER})"
  create_args=(
    cluster create
    --name "${CLUSTER_NAME}"
    --provisioner "${PROVISIONER}"
    --talos-version "v${TALOS_VERSION}"
    --controlplanes 1
    --workers 1
    --config-patch "@${BASE_PATCH}"
    --config-patch-control-plane "@${BOOTSTRAP_PATCH}"
    --wait
    --wait-timeout 15m
  )
  if [ "${PROVISIONER}" = "qemu" ]; then
    create_args+=(
      --cpus 2
      --memory 3072
      --cpus-workers 2
      --memory-workers 4096
      --disk 10240
    )
  fi
  talos "${create_args[@]}"

  echo ">>> Fetching kubeconfig"
  talos kubeconfig "${KUBECONFIG_OUT}" --force
  if [ -n "${SUDO}" ]; then
    ${SUDO} chown -R "$(id -u):$(id -g)" "${OUT_DIR}"
  fi
  export KUBECONFIG="${KUBECONFIG_OUT}"

  echo ">>> Waiting for Talos health"
  talos health --wait-timeout 10m

  echo ">>> Waiting for nodes and the bootstrap layer"
  kubectl wait --for=condition=Ready nodes --all --timeout=600s
  kubectl -n kube-system rollout status daemonset/cilium --timeout=600s
  kubectl -n cert-manager rollout status deploy/cert-manager --timeout=600s
  kubectl -n argocd rollout status deploy/argocd-server --timeout=600s
  kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=600s
  kubectl -n gateway-system get gateway public

  echo ">>> Scheduling smoke pod"
  kubectl run smoke --image=registry.k8s.io/pause:3.10 --restart=Never
  kubectl wait --for=condition=Ready pod/smoke --timeout=300s
  kubectl delete pod smoke --wait=false

  echo ""
  echo "Local Talos cluster is up. Use it with:"
  echo "  export KUBECONFIG=${KUBECONFIG_OUT}"
  echo "  export TALOSCONFIG=${TALOSCONFIG_OUT}"
  echo "Tear it down with: $0 down"
}

down() {
  ${SUDO} talosctl cluster destroy --name "${CLUSTER_NAME}" --provisioner "${PROVISIONER}"
}

status() {
  ${SUDO} talosctl cluster show --name "${CLUSTER_NAME}" --provisioner "${PROVISIONER}"
}

case "${CMD}" in
  up) up ;;
  down) down ;;
  status) status ;;
  *)
    echo "usage: $0 [up|down|status]" >&2
    exit 64
    ;;
esac
