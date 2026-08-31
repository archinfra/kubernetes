#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/hack/lib/common.sh"
load_version

ARCH="$(normalize_arch "${ARCH:-amd64}")"
IMAGE="${IMAGE:-localhost/archinfra/kubernetes:${KUBE_VERSION}-${ARCH}}"
SEALOS="$(sealos_bin)"
SUDO=""
[[ "$EUID" -eq 0 ]] || SUDO=sudo

for cmd in tar sha256sum; do require_cmd "$cmd"; done

STAGE_ROOT="$ROOT/dist/stage"
STAGE="$STAGE_ROOT/apps_kubernetes"
ARCHIVE="$ROOT/dist/apps_kubernetes-${KUBE_VERSION}-linux-${ARCH}.tar.gz"
IMAGE_TAR="kubernetes-${KUBE_VERSION}-${ARCH}.tar"
rm -rf "$STAGE_ROOT"
mkdir -p "$STAGE/bin" "$STAGE/images" "$STAGE/manifests" "$STAGE/configs" "$STAGE/scripts"

log "saving Sealos cluster image"
$SUDO "$SEALOS" save -o "$STAGE/images/$IMAGE_TAR" "$IMAGE"
cp -a "$SEALOS" "$STAGE/bin/sealos"
cp -a "$ROOT/packaging/scripts/install.sh" "$STAGE/scripts/install.sh"
cp -a "$ROOT/packaging/scripts/verify.sh" "$STAGE/scripts/verify.sh"
cp -a "$ROOT/configs/." "$STAGE/configs/"
chmod +x "$STAGE/bin/sealos" "$STAGE/scripts/"*.sh

cat > "$STAGE/manifests/release.env" <<EOF
PACKAGE_NAME=apps_kubernetes
PACKAGE_FORMAT_VERSION=1
KUBE_VERSION=${KUBE_VERSION}
ARCH=${ARCH}
CLUSTER_IMAGE=${IMAGE}
CLUSTER_IMAGE_ARCHIVE=images/${IMAGE_TAR}
SEALOS_VERSION=${SEALOS_VERSION}
CONTAINERD_SERIES=${CONTAINERD_SERIES}
CONTAINERD_VALIDATED_VERSION=${CONTAINERD_VALIDATED_VERSION}
RUNC_MIN_VERSION=${RUNC_MIN_VERSION}
UPSTREAM_RUNTIME_COMMIT=${UPSTREAM_RUNTIME_COMMIT}
EOF

{
  echo "repository=archinfra/kubernetes"
  echo "built_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "host=$(uname -a)"
  echo "sealos_version=$($SEALOS version 2>/dev/null | tr '\n' ' ' || true)"
} > "$STAGE/manifests/provenance.txt"

(
  cd "$STAGE"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)

tar -C "$STAGE_ROOT" -czf "$ARCHIVE" apps_kubernetes
log "delivery package: $ARCHIVE"
