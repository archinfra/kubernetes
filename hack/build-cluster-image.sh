#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/hack/lib/common.sh"
load_version

ARCH="$(normalize_arch "${ARCH:-amd64}")"
IMAGE="${IMAGE:-localhost/archinfra/kubernetes:${KUBE_VERSION}-${ARCH}}"
SEALOS="$(sealos_bin)"
CACHE="${UPSTREAM_CACHE}"
KUBE="${KUBE_VERSION#v}"
KUBE_XY="${KUBE%.*}"
SEALOS_NO_V="${SEALOS_VERSION#v}"
SUDO=""
[[ "$EUID" -eq 0 ]] || SUDO=sudo

for cmd in buildah file grep sed tar; do require_cmd "$cmd"; done

# Build our own pinned containerd+runc bundle first. The Sealos cache is not authoritative for CRI versions.
VERSION="$KUBE_VERSION" ARCH="$ARCH" "$ROOT/hack/build-runtime-bundle.sh"
RUNTIME_BUNDLE="$ROOT/dist/cache/cri-containerd-${CONTAINERD_VERSION}-${RUNC_VERSION}-${ARCH}.tar.gz"
[[ -f "$RUNTIME_BUNDLE" ]] || die "runtime bundle missing: $RUNTIME_BUNDLE"

WORK="$ROOT/.work/${KUBE_VERSION}-${ARCH}"
ROOTFS="$WORK/rootfs"
rm -rf "$WORK"
mkdir -p "$ROOTFS/bin" "$ROOTFS/cri" "$ROOTFS/opt" "$ROOTFS/images/shim"

cp -a "$ROOT/runtime/containerd/." "$ROOTFS/"
cp -a "$ROOT/runtime/registry/." "$ROOTFS/"
cp -a "$ROOT/runtime/k8s/." "$ROOTFS/"

containers=()
mount_image() {
  local image ctr mnt
  image="$1"
  ctr="$($SUDO buildah from "$image")"
  containers+=("$ctr")
  mnt="$($SUDO buildah mount "$ctr")"
  echo "$mnt"
}

cleanup() {
  set +e
  $SUDO buildah umount --all >/dev/null 2>&1
  for ctr in "${containers[@]:-}"; do $SUDO buildah rm "$ctr" >/dev/null 2>&1; done
}
trap cleanup EXIT

log "mounting pinned upstream cache inputs"
MOUNT_CRI="$(mount_image "$CACHE:cri-$ARCH")"
MOUNT_KUBE="$(mount_image "$CACHE:kubernetes-v${KUBE}-$ARCH")"
MOUNT_CRIO="$(mount_image "$CACHE:cri-v${KUBE_XY}-$ARCH")"
MOUNT_SEALOS="$(mount_image "$CACHE:sealos-v${SEALOS_NO_V}-$ARCH")"

# Sealos bootstrap helpers.
cp -a "$MOUNT_SEALOS/sealos/image-cri-shim" "$ROOTFS/cri/"
cp -a "$MOUNT_SEALOS/sealos/sealctl" "$ROOTFS/opt/"

# Kubernetes-adjacent node tools remain sourced from the pinned upstream cache for V1.
tar -xzf "$MOUNT_CRIO/cri/crictl.tar.gz" -C "$ROOTFS/bin/"
cp -a "$MOUNT_CRI/cri/conntrack" "$ROOTFS/bin/"
cp -a "$MOUNT_CRI/cri/lsof" "$ROOTFS/opt/"
cp -a "$MOUNT_CRI/cri/registry" "$ROOTFS/cri/"
cp -a "$MOUNT_CRI/cri/libseccomp.tar.gz" "$ROOTFS/cri/"

# The CRI runtime itself is Archinfra-owned and version-pinned.
cp -a "$RUNTIME_BUNDLE" "$ROOTFS/cri/cri-containerd.tar.gz"

# Keep Kubefile based on the exact Kubernetes cache image so kubeadm/kubelet,
# image lists and embedded registry content are version aligned.
sed -E "s#^FROM .+#FROM ${CACHE}:kubernetes-v${KUBE}-${ARCH}#" \
  "$ROOTFS/Kubefile" > "$ROOTFS/Kubefile.tmp"
mv "$ROOTFS/Kubefile.tmp" "$ROOTFS/Kubefile"

pause_image="$(grep '/pause:' "$MOUNT_KUBE/images/shim/DefaultImageList" | head -n1)"
[[ -n "$pause_image" ]] || die "pause image not found in Kubernetes cache"
ipvs_image="ghcr.io/labring/lvscare:${SEALOS_VERSION}"

log "building cluster image $IMAGE"
cd "$ROOTFS"
$SUDO "$SEALOS" build \
  --label="sealos.io.type=rootfs" \
  --label="sealos.io.version=v1beta1" \
  --label="version=${KUBE_VERSION}" \
  --label="org.archinfra.upstream-runtime=${UPSTREAM_RUNTIME_COMMIT}" \
  --label="org.archinfra.containerd=${CONTAINERD_VERSION}" \
  --label="org.archinfra.runc=${RUNC_VERSION}" \
  --label="image=${ipvs_image}" \
  --env="defaultVIP=${DEFAULT_VIP}" \
  --env="sandboxImage=${pause_image#*/}" \
  --platform="linux/${ARCH}" \
  -t "$IMAGE" .

mkdir -p "$ROOT/dist/meta"
cat > "$ROOT/dist/meta/cluster-image.env" <<EOF
KUBE_VERSION=${KUBE_VERSION}
ARCH=${ARCH}
CLUSTER_IMAGE=${IMAGE}
SEALOS_VERSION=${SEALOS_VERSION}
UPSTREAM_RUNTIME_COMMIT=${UPSTREAM_RUNTIME_COMMIT}
CONTAINERD_VERSION=${CONTAINERD_VERSION}
RUNC_VERSION=${RUNC_VERSION}
EOF

log "cluster image built: $IMAGE"
