#!/usr/bin/env bash
# Wait for Kubernetes cluster to be healthy and all expected nodes to register.
# Prerequisites: kubectl configured via KUBECONFIG env var.
# Usage: wait-for-cluster.sh <node1> [node2 ...]

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <node1> [node2 ...]" >&2
  exit 1
fi

EXPECTED_NODES=("$@")
TIMEOUT=300
INTERVAL=5
ATTEMPTS=$((TIMEOUT / INTERVAL))

# Wait for apiserver to be healthy
for i in $(seq 1 "$ATTEMPTS"); do
  if kubectl get --raw /healthz >/dev/null 2>&1; then
    echo "apiserver /healthz OK"
    break
  fi
  echo "waiting for apiserver (attempt $i/$ATTEMPTS)..."
  sleep "$INTERVAL"
done

kubectl get --raw /healthz >/dev/null || {
  echo "apiserver /healthz check failed after $TIMEOUT seconds" >&2
  exit 1
}

# Wait for all nodes to register
for i in $(seq 1 "$ATTEMPTS"); do
  missing=""
  for node in "${EXPECTED_NODES[@]}"; do
    if ! kubectl get node "$node" >/dev/null 2>&1; then
      missing="$missing $node"
    fi
  done
  if [[ -z "$missing" ]]; then
    echo "all nodes registered: ${EXPECTED_NODES[*]}"
    exit 0
  fi
  echo "waiting for nodes to register, missing:$missing (attempt $i/$ATTEMPTS)..."
  sleep "$INTERVAL"
done

echo "nodes never registered within $TIMEOUT seconds: $missing" >&2
exit 1
