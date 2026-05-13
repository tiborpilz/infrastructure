#!/usr/bin/env bash
set -euo pipefail

TALOS_VERSION="${TALOS_VERSION:-v1.13.0}"
ARCH="${ARCH:-amd64}"
TALOS_EXTENSIONS="${TALOS_EXTENSIONS:-siderolabs/qemu-guest-agent siderolabs/iscsi-tools siderolabs/util-linux-tools}"
SCHEMATIC_ID="${SCHEMATIC_ID:-}"

if [[ -z "${HCLOUD_TOKEN:-}" ]]; then
  echo "HCLOUD_TOKEN env var must be set" >&2
  exit 1
fi

for cmd in hcloud hcloud-upload-image curl jq; do
  command -v "$cmd" >/dev/null || { echo "missing required tool: $cmd (run \`nix develop\` or \`direnv allow\`)" >&2; exit 1; }
done

case "$ARCH" in
  amd64) HCLOUD_ARCH="x86" ;;
  arm64) HCLOUD_ARCH="arm" ;;
  *) echo "unsupported ARCH: $ARCH (must be amd64 or arm64)" >&2; exit 1 ;;
esac

VERSION_NO_V="${TALOS_VERSION#v}"

# Resolve schematic ID via the factory API if not pinned. The schematic is a
# canonical hash of the extension list — same extensions always produce the
# same ID, different extensions produce different IDs. That's exactly what we
# need for snapshot idempotency.
if [[ -z "$SCHEMATIC_ID" ]]; then
  echo "Resolving schematic ID for extensions: $TALOS_EXTENSIONS"
  SCHEMATIC_BODY="customization:
  systemExtensions:
    officialExtensions:
$(for ext in $TALOS_EXTENSIONS; do echo "      - $ext"; done)"

  SCHEMATIC_ID=$(
    curl -fsSL -X POST --data-binary "$SCHEMATIC_BODY" \
      https://factory.talos.dev/schematics \
      | jq -r '.id'
  )
  echo "  -> $SCHEMATIC_ID"
fi

# Hetzner label values: max 63 chars, regex [A-Za-z0-9._-] with alphanumeric
# start/end. Full schematic IDs are 64-char SHA256 hex — one char over the
# cap. 16 hex chars = 64 bits of uniqueness, plenty for distinguishing image
# snapshots. The version label (e.g. "1.13.0") fits the regex because dots
# are allowed mid-value and the value starts/ends with a digit.
SCHEMATIC_SHORT="${SCHEMATIC_ID:0:16}"
LABEL_SELECTOR="os=talos,version=${VERSION_NO_V},arch=${ARCH},schematic=${SCHEMATIC_SHORT}"

# Idempotency: skip if a matching snapshot already exists.
EXISTING="$(hcloud image list --type snapshot --selector "$LABEL_SELECTOR" -o noheader -o columns=id || true)"

if [[ -n "$EXISTING" ]]; then
  echo "Snapshot already exists (id ${EXISTING}) for talos ${TALOS_VERSION} ${ARCH}. Nothing to do."
  exit 0
fi

URL="https://factory.talos.dev/image/${SCHEMATIC_ID}/${TALOS_VERSION}/hcloud-${ARCH}.raw.xz"

echo
echo "Uploading Talos ${TALOS_VERSION} (${ARCH}) from:"
echo "  $URL"
echo

hcloud-upload-image upload \
  --image-url    "$URL" \
  --compression  xz \
  --architecture "$HCLOUD_ARCH" \
  --description  "talos-${VERSION_NO_V}-${ARCH}" \
  --labels       "$LABEL_SELECTOR"

echo
echo "Done. Snapshots matching labels:"
hcloud image list --type snapshot --selector "$LABEL_SELECTOR"
