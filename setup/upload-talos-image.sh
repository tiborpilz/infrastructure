#!/usr/bin/env bash
set -euo pipefail

# One-time Talos image uploader for Hetzner Cloud.
# Idempotent: skips if a snapshot with matching labels already exists.
#
# Tools required (provided by the dev shell — `nix develop` or `direnv allow`):
#   hcloud, hcloud-upload-image, curl, jq
#
# Required env:
#   HCLOUD_TOKEN   Hetzner Cloud API token (read+write)
#
# Optional env:
#   TALOS_VERSION      default v1.13.0 (must match talos_image_labels.version in env.hcl, with leading 'v')
#   ARCH               default amd64   (must match talos_image_labels.arch; one of: amd64, arm64)
#   TALOS_EXTENSIONS   space-separated list of factory extensions; default:
#                        "siderolabs/qemu-guest-agent"
#                      Hetzner Cloud platform support is built into Talos core
#                      (no extension needed); qemu-guest-agent enables clean
#                      Velero snapshots later.
#   SCHEMATIC_ID       pin a specific schematic; skips the factory API call

TALOS_VERSION="${TALOS_VERSION:-v1.13.0}"
ARCH="${ARCH:-amd64}"
TALOS_EXTENSIONS="${TALOS_EXTENSIONS:-siderolabs/qemu-guest-agent}"
SCHEMATIC_ID="${SCHEMATIC_ID:-}"

if [[ -z "${HCLOUD_TOKEN:-}" ]]; then
  echo "HCLOUD_TOKEN env var must be set" >&2
  exit 1
fi

for cmd in hcloud hcloud-upload-image curl jq; do
  command -v "$cmd" >/dev/null || { echo "missing required tool: $cmd (run \`nix develop\` or \`direnv allow\`)" >&2; exit 1; }
done

# hcloud-upload-image uses x86/arm; Talos labels use amd64/arm64. Translate.
case "$ARCH" in
  amd64) HCLOUD_ARCH="x86" ;;
  arm64) HCLOUD_ARCH="arm" ;;
  *) echo "unsupported ARCH: $ARCH (must be amd64 or arm64)" >&2; exit 1 ;;
esac

VERSION_NO_V="${TALOS_VERSION#v}"
LABEL_SELECTOR="os=talos,version=${VERSION_NO_V},arch=${ARCH}"

# Resolve schematic ID via the factory API if not pinned.
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
