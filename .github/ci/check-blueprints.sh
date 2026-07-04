#!/usr/bin/env bash
# Asserts against a running authentik that every custom blueprint shipped via
# the aggregated ConfigMap applied cleanly, then spot-checks the end state the
# blueprints declare. Requires AUTHENTIK_TOKEN (bootstrap API token).
set -euo pipefail

HOST="${AUTHENTIK_HOST:-http://127.0.0.1:9000}"
TOKEN="${AUTHENTIK_TOKEN:?AUTHENTIK_TOKEN is required}"

api() {
  curl -sf -H "Authorization: Bearer ${TOKEN}" "${HOST}/api/v3${1}"
}

echo "Waiting for the authentik API..."
for i in $(seq 1 30); do
  if api '/root/config/' >/dev/null 2>&1; then
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "authentik API did not become reachable at ${HOST}" >&2
    exit 1
  fi
  sleep 5
done

echo "Waiting for blueprint instances to apply..."
blueprints="{}"
for i in $(seq 1 60); do
  blueprints="$(api '/managed/blueprints/?page_size=100' || echo '{}')"
  custom="$(jq '[.results[]? | select(.path | startswith("custom/"))] | length' <<<"${blueprints}")"
  bad_custom="$(jq '[.results[]? | select((.path | startswith("custom/")) and .status != "successful")] | length' <<<"${blueprints}")"
  if [ "${custom}" -gt 0 ] && [ "${bad_custom}" -eq 0 ]; then
    echo "All ${custom} custom blueprint instances applied successfully:"
    jq -r '.results[] | select(.path | startswith("custom/")) | "  \(.status)\t\(.path)"' <<<"${blueprints}"
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "Custom blueprint instances that did not apply:" >&2
    jq -r '.results[]? | select(.status != "successful") | "  \(.status)\t\(.path)\t\(.name)"' <<<"${blueprints}" >&2
    exit 1
  fi
  sleep 5
done

# Bundled default blueprints are informational only - they are not part of this repo.
jq -r '.results[]? | select((.path | startswith("custom/") | not) and .status != "successful") | "note: bundled blueprint not successful: \(.status)\t\(.path)"' <<<"${blueprints}"

echo "Checking the end state declared by the custom blueprints..."

identification="$(api '/stages/identification/')"
jq -e '[.results[] | select(.name == "default-authentication-identification")][0].password_stage != null' <<<"${identification}" >/dev/null \
  || { echo "identification stage has no password stage bound (combined login page missing)" >&2; exit 1; }
echo "  identification stage has the password stage bound (single-page login)"

login="$(api '/stages/user_login/')"
jq -e '[.results[] | select(.name == "default-authentication-login")][0].session_duration == "days=30"' <<<"${login}" >/dev/null \
  || { echo "user login stage session_duration is not days=30" >&2; exit 1; }
echo "  user login stage keeps sessions for 30 days"

users="$(api '/core/users/?username=tibor')"
jq -e '.results | length == 1' <<<"${users}" >/dev/null \
  || { echo "managed user 'tibor' was not created by the users blueprint" >&2; exit 1; }
echo "  users blueprint created the managed user (validates !File password mounts)"

echo "Blueprint end-state checks passed."
