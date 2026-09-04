#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/hack/lib/common.sh"
load_version
ARCH="$(normalize_arch "${ARCH:-amd64}")"
ARCHIVE="$ROOT/dist/apps_kubernetes-${KUBE_VERSION}-linux-${ARCH}.tar.gz"
[[ -f "$ARCHIVE" ]] || die "package not found: $ARCHIVE"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
tar -xzf "$ARCHIVE" -C "$tmp"
"$tmp/apps_kubernetes/scripts/verify.sh"
log "package verified: $ARCHIVE"
