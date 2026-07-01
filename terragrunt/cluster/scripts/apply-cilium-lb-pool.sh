#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <floating-ip>" >&2
  exit 1
fi

FLOATING_IP="$1"
TIMEOUT=300
INTERVAL=5
ATTEMPTS=$((TIMEOUT / INTERVAL))

for i in $(seq 1 "$ATTEMPTS"); do
  if kubectl get crd ciliumloadbalancerippools.cilium.io >/dev/null 2>&1; then
    echo "CiliumLoadBalancerIPPool CRD available"
    break
  fi
  echo "waiting for CiliumLoadBalancerIPPool CRD (attempt $i/$ATTEMPTS)..."
  sleep "$INTERVAL"
done

kubectl get crd ciliumloadbalancerippools.cilium.io >/dev/null 2>&1 || {
  echo "CiliumLoadBalancerIPPool CRD never registered within $TIMEOUT seconds" >&2
  exit 1
}

kubectl apply -f - <<YAML
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: default
spec:
  blocks:
    - start: "$FLOATING_IP"
      stop: "$FLOATING_IP"
YAML
