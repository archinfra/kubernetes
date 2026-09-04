#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/hack/lib/common.sh"
load_version
ARCH="$(normalize_arch "${ARCH:-amd64}")"

for cmd in curl tar sha256sum install; do require_cmd "$cmd"; done

case "$ARCH" in
  amd64)
    containerd_sha="$CONTAINERD_SHA256_AMD64"
    runc_sha="$RUNC_SHA256_AMD64"
    ;;
  arm64)
    containerd_sha="$CONTAINERD_SHA256_ARM64"
    runc_sha="$RUNC_SHA256_ARM64"
    ;;
esac

containerd_no_v="${CONTAINERD_VERSION#v}"
runc_asset="runc.${ARCH}"
containerd_asset="containerd-${containerd_no_v}-linux-${ARCH}.tar.gz"
containerd_url="https://github.com/containerd/containerd/releases/download/${CONTAINERD_VERSION}/${containerd_asset}"
runc_url="https://github.com/opencontainers/runc/releases/download/${RUNC_VERSION}/${runc_asset}"

cache="$ROOT/.cache/downloads/runtime"
outdir="$ROOT/dist/cache"
work="$ROOT/.work/runtime-${CONTAINERD_VERSION}-${RUNC_VERSION}-${ARCH}"
out="$outdir/cri-containerd-${CONTAINERD_VERSION}-${RUNC_VERSION}-${ARCH}.tar.gz"
mkdir -p "$cache" "$outdir"
rm -rf "$work"
mkdir -p "$work/containerd" "$work/bundle/cri/bin"

fetch_verified() {
  local url="$1" file="$2" expected="$3" actual
  if [[ ! -f "$file" ]]; then
    log "download $url"
    curl -fL --retry 5 --retry-delay 2 -o "$file" "$url"
  fi
  actual="$(sha256_file "$file")"
  [[ "$actual" == "$expected" ]] || die "sha256 mismatch for $file: expected=$expected actual=$actual"
}

containerd_file="$cache/$containerd_asset"
runc_file="$cache/$runc_asset-${RUNC_VERSION}"
fetch_verified "$containerd_url" "$containerd_file" "$containerd_sha"
fetch_verified "$runc_url" "$runc_file" "$runc_sha"

tar -xzf "$containerd_file" -C "$work/containerd"
[[ -d "$work/containerd/bin" ]] || die "containerd release archive has no bin/ directory"
cp -a "$work/containerd/bin/." "$work/bundle/cri/bin/"
install -m 0755 "$runc_file" "$work/bundle/cri/bin/runc"

# Sealos' runtime installer extracts this bundle with --strip-components=2.
tar -C "$work/bundle" -czf "$out" cri/bin

cat > "$out.manifest" <<EOF
containerd=${CONTAINERD_VERSION}
containerd_sha256=${containerd_sha}
runc=${RUNC_VERSION}
runc_sha256=${runc_sha}
arch=${ARCH}
bundle_sha256=$(sha256_file "$out")
EOF

log "runtime bundle: $out"
