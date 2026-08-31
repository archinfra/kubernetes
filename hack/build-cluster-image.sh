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
MOUNT_TOOLS="$(mount_image "$CACHE:tools-$ARCH")"
MOUNT_SEALOS="$(mount_image "$CACHE:sealos-v${SEALOS_NO_V}-$ARCH")"

# Sealos runtime helpers.
cp -a "$MOUNT_SEALOS/sealos/image-cri-shim" "$ROOTFS/cri/"
cp -a "$MOUNT_SEALOS/sealos/sealctl" "$ROOTFS/opt/"

# Runtime and node tools follow the proven labring-actions/runtime layout.
tar -xzf "$MOUNT_CRIO/cri/crictl.tar.gz" -C "$ROOTFS/bin/"
cp -a "$MOUNT_CRI/cri/conntrack" "$ROOTFS/bin/"
cp -a "$MOUNT_CRI/cri/lsof" "$ROOTFS/opt/"
cp -a "$MOUNT_CRI/cri/registry" "$ROOTFS/cri/"
cp -a "$MOUNT_CRI/cri/libseccomp.tar.gz" "$ROOTFS/cri/"
cp -a "$MOUNT_CRI/cri/cri-containerd.tar.gz" "$ROOTFS/cri/"

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
  --label="org.archinfra.containerd-line=${CONTAINERD_SERIES}" \
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
CONTAINERD_SERIES=${CONTAINERD_SERIES}
EOF

log "cluster image built: $IMAGE"
