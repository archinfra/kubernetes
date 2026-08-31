#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ -f manifests/release.env ]] || { echo 'missing manifests/release.env' >&2; exit 1; }
[[ -f SHA256SUMS ]] || { echo 'missing SHA256SUMS' >&2; exit 1; }
sha256sum -c SHA256SUMS
# shellcheck disable=SC1091
source manifests/release.env
[[ -x bin/sealos ]] || { echo 'missing bin/sealos' >&2; exit 1; }
[[ -f "$CLUSTER_IMAGE_ARCHIVE" ]] || { echo "missing $CLUSTER_IMAGE_ARCHIVE" >&2; exit 1; }
echo "apps_kubernetes verified: Kubernetes=$KUBE_VERSION arch=$ARCH"
