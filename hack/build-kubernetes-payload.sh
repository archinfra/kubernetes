#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/hack/lib/common.sh"
load_version

ARCH="$(normalize_arch "${ARCH:-amd64}")"
HOST_ARCH="$(normalize_arch "$(uname -m)")"
require_cmd curl
require_cmd sha256sum
require_cmd tar

DOWNLOAD_ROOT="$ROOT/.cache/downloads/kubernetes/${KUBE_VERSION}"
PAYLOAD="$ROOT/dist/cache/kubernetes-payload-${KUBE_VERSION}-${ARCH}"
rm -rf "$PAYLOAD"
mkdir -p "$DOWNLOAD_ROOT/$ARCH" "$DOWNLOAD_ROOT/$HOST_ARCH" "$PAYLOAD/bin" "$PAYLOAD/images/shim"

fetch_kube_binary() {
  local arch="$1"
  local name="$2"
  local out="$3"
  local dir="$DOWNLOAD_ROOT/$arch"
  local file="$dir/$name"
  local sum="$dir/$name.sha256"
  local base="https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${arch}/${name}"
  local expected actual

  mkdir -p "$dir"
  if [[ ! -s "$file" ]]; then
    log "download Kubernetes ${name} ${KUBE_VERSION} linux/${arch}"
    curl -fL --retry 5 --retry-delay 2 -o "$file" "$base"
  fi
  if [[ ! -s "$sum" ]]; then
    curl -fL --retry 5 --retry-delay 2 -o "$sum" "${base}.sha256"
  fi
  expected="$(tr -d '[:space:]' < "$sum")"
  actual="$(sha256_file "$file")"
  [[ "$actual" == "$expected" ]] || die "Kubernetes binary checksum mismatch: $name linux/$arch expected=$expected actual=$actual"
  install -m 0755 "$file" "$out"
}

for binary in kubeadm kubelet kubectl; do
  fetch_kube_binary "$ARCH" "$binary" "$PAYLOAD/bin/$binary"
done

# kubeadm image names are multi-arch references. For cross-builds we run the
# host-architecture kubeadm of the exact same Kubernetes version only to render
# the canonical image list.
HOST_KUBEADM="$PAYLOAD/bin/kubeadm"
if [[ "$HOST_ARCH" != "$ARCH" ]]; then
  HOST_KUBEADM="$DOWNLOAD_ROOT/$HOST_ARCH/kubeadm.host"
  fetch_kube_binary "$HOST_ARCH" kubeadm "$HOST_KUBEADM"
fi

"$HOST_KUBEADM" config images list --kubernetes-version "$KUBE_VERSION" \
  > "$PAYLOAD/images/shim/DefaultImageList"

grep -q '/pause:' "$PAYLOAD/images/shim/DefaultImageList" \
  || die "kubeadm image list does not contain a pause image"

case "$ARCH" in
  amd64) CRICTL_SHA="$CRICTL_SHA256_AMD64" ;;
  arm64) CRICTL_SHA="$CRICTL_SHA256_ARM64" ;;
esac
CRICTL_ASSET="crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz"
CRICTL_FILE="$ROOT/.cache/downloads/${CRICTL_ASSET}"
CRICTL_URL="https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/${CRICTL_ASSET}"
mkdir -p "$(dirname "$CRICTL_FILE")"
if [[ ! -s "$CRICTL_FILE" ]]; then
  log "download ${CRICTL_ASSET}"
  curl -fL --retry 5 --retry-delay 2 -o "$CRICTL_FILE" "$CRICTL_URL"
fi
[[ "$(sha256_file "$CRICTL_FILE")" == "$CRICTL_SHA" ]] \
  || die "crictl checksum mismatch for linux/$ARCH"
tar -xzf "$CRICTL_FILE" -C "$PAYLOAD/bin" crictl
chmod 0755 "$PAYLOAD/bin/crictl"

MANIFEST="$ROOT/dist/cache/kubernetes-payload-${KUBE_VERSION}-${ARCH}.manifest"
{
  echo "kubernetes=${KUBE_VERSION}"
  echo "arch=${ARCH}"
  echo "kubeadm_sha256=$(sha256_file "$PAYLOAD/bin/kubeadm")"
  echo "kubelet_sha256=$(sha256_file "$PAYLOAD/bin/kubelet")"
  echo "kubectl_sha256=$(sha256_file "$PAYLOAD/bin/kubectl")"
  echo "crictl=${CRICTL_VERSION}"
  echo "crictl_sha256=$(sha256_file "$CRICTL_FILE")"
  echo "image_list_sha256=$(sha256_file "$PAYLOAD/images/shim/DefaultImageList")"
  echo "image_count=$(grep -cve '^[[:space:]]*$' "$PAYLOAD/images/shim/DefaultImageList")"
} > "$MANIFEST"

log "Kubernetes payload: $PAYLOAD"
log "Kubernetes payload manifest: $MANIFEST"
