#!/usr/bin/env bash
# Wait for the given Proxmox-hosted Talos nodes to register, then remove the
# external-cloud-provider "uninitialized" taint. These nodes have no CCM to
# clear it (hcloud-ccm only manages hcloud nodes), so they would stay
# unschedulable otherwise.
# Prerequisites: kubectl configured via KUBECONFIG env var.
# Usage: wait-and-untaint.sh <node1> [node2 ...]

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <node1> [node2 ...]" >&2
  exit 1
fi

NODES=("$@")
TAINT="node.cloudprovider.kubernetes.io/uninitialized"
TIMEOUT=600
INTERVAL=10
ATTEMPTS=$((TIMEOUT / INTERVAL))

for node in "${NODES[@]}"; do
  registered=false
  for i in $(seq 1 "$ATTEMPTS"); do
    if kubectl get node "$node" >/dev/null 2>&1; then
      registered=true
      break
    fi
    echo "waiting for node $node to register (attempt $i/$ATTEMPTS)..."
    sleep "$INTERVAL"
  done

  if [[ "$registered" != true ]]; then
    echo "node $node never registered within $TIMEOUT seconds" >&2
    exit 1
  fi

  # kubelet adds the taint at registration; remove it and confirm it stays gone.
  for attempt in 1 2 3; do
    kubectl taint node "$node" "${TAINT}:NoSchedule-" 2>/dev/null || true
    if ! kubectl get node "$node" -o jsonpath='{.spec.taints[*].key}' 2>/dev/null | grep -q "$TAINT"; then
      echo "untainted $node"
      break
    fi
    echo "taint still present on $node, retrying ($attempt/3)..."
    sleep "$INTERVAL"
  done
done

echo "all proxmox nodes registered and untainted: ${NODES[*]}"
