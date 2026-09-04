#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/hack/lib/common.sh"
load_version

ARCH="$(normalize_arch "${ARCH:-$(uname -m)}")"
require_cmd curl
require_cmd tar
require_cmd sha256sum

case "$ARCH" in
  amd64) expected="$SEALOS_SHA256_AMD64" ;;
  arm64) expected="$SEALOS_SHA256_ARM64" ;;
esac

version_no_v="${SEALOS_VERSION#v}"
url="https://github.com/labring/sealos/releases/download/${SEALOS_VERSION}/sealos_${version_no_v}_linux_${ARCH}.tar.gz"
cache="$ROOT/.cache/downloads"
bindir="$ROOT/.cache/bin"
archive="$cache/sealos_${version_no_v}_linux_${ARCH}.tar.gz"
mkdir -p "$cache" "$bindir"

if [[ ! -f "$archive" ]]; then
  log "download $url"
  curl -fL --retry 5 --retry-delay 2 -o "$archive" "$url"
fi

actual="$(sha256_file "$archive")"
[[ "$actual" == "$expected" ]] || die "sealos sha256 mismatch: expected=$expected actual=$actual"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
tar -xzf "$archive" -C "$tmp"
found="$(find "$tmp" -type f -name sealos -perm -u+x | head -n1 || true)"
[[ -n "$found" ]] || die "sealos binary not found in release archive"
install -m 0755 "$found" "$bindir/sealos"

log "installed $($bindir/sealos version 2>/dev/null | head -n1 || echo sealos-$SEALOS_VERSION)"
