# Sourced by every script that shells out to kubectl.
#
# kubectl treats an unset or dangling KUBECONFIG as "no cluster configured" and
# quietly falls back to localhost, so a missing file turns into a full timeout
# spent polling nothing. Fail on the real cause instead.

if [[ -z "${KUBECONFIG:-}" ]]; then
  echo "KUBECONFIG is unset" >&2
  exit 1
fi

if [[ ! -s "$KUBECONFIG" ]]; then
  echo "KUBECONFIG points at $KUBECONFIG, which is missing or empty." >&2
  echo "Write it from state with ./setup/write-local-configs.sh" >&2
  exit 1
fi
