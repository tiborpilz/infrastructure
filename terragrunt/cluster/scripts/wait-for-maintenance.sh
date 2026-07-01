#!/usr/bin/env bash

set -euo pipefail

HOST="${1:?Missing required argument: host}"
TIMEOUT="${2:-300}"
INTERVAL=5
ATTEMPTS=$((TIMEOUT / INTERVAL))

for i in $(seq 1 "$ATTEMPTS"); do
  if (echo > /dev/tcp/"$HOST"/50000) 2>/dev/null; then
    echo "Talos maintenance API reachable on $HOST"
    exit 0
  fi
  echo "waiting for Talos maintenance API on $HOST (attempt $i/$ATTEMPTS)..."
  sleep "$INTERVAL"
done

echo "Talos maintenance API on $HOST never came up after $TIMEOUT seconds" >&2
exit 1
