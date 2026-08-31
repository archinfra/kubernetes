#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/hack/lib/common.sh"
load_version
ARCH="$(normalize_arch "${ARCH:-$(uname -m)}")"

for cmd in curl tar sha256sum file buildah; do
  require_cmd "$cmd"
done

SEALOS="$(sealos_bin)"
log "version: $KUBE_VERSION"
log "arch: $ARCH"
log "sealos: $SEALOS_VERSION ($SEALOS)"
log "containerd validation line: $CONTAINERD_VALIDATED_VERSION"
log "upstream runtime commit: $UPSTREAM_RUNTIME_COMMIT"

if ! "$SEALOS" version >/dev/null 2>&1; then
  die "sealos binary cannot execute"
fi

if [[ "$EUID" -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
  die "root or sudo is required for rootful buildah/sealos build"
fi

log "preflight passed"
