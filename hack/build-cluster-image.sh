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
SEALOS_NO_V="${SEALOS_VERSION#v}"
SUDO=""
[[ "$EUID" -eq 0 ]] || SUDO=sudo

for cmd in buildah file grep tar; do require_cmd "$cmd"; done

# Archinfra owns both the Kubernetes node payload and the CRI runtime versions.
VERSION="$KUBE_VERSION" ARCH="$ARCH" "$ROOT/hack/build-kubernetes-payload.sh"
VERSION="$KUBE_VERSION" ARCH="$ARCH" "$ROOT/hack/build-runtime-bundle.sh"

PAYLOAD="$ROOT/dist/cache/kubernetes-payload-${KUBE_VERSION}-${ARCH}"
RUNTIME_BUNDLE="$ROOT/dist/cache/cri-containerd-${CONTAINERD_VERSION}-${RUNC_VERSION}-${ARCH}.tar.gz"
[[ -d "$PAYLOAD" ]] || die "Kubernetes payload missing: $PAYLOAD"
[[ -f "$RUNTIME_BUNDLE" ]] || die "runtime bundle missing: $RUNTIME_BUNDLE"

WORK="$ROOT/.work/${KUBE_VERSION}-${ARCH}"
ROOTFS="$WORK/rootfs"
rm -rf "$WORK"
mkdir -p "$ROOTFS/bin" "$ROOTFS/cri" "$ROOTFS/opt" "$ROOTFS/images/shim"

cp -a "$ROOT/runtime/containerd/." "$ROOTFS/"
cp -a "$ROOT/runtime/registry/." "$ROOTFS/"
cp -a "$ROOT/runtime/k8s/." "$ROOTFS/"
cp -a "$PAYLOAD/bin/." "$ROOTFS/bin/"
cp -a "$PAYLOAD/images/." "$ROOTFS/images/"

mount_image() {
  local image ctr
  image="$1"
  ctr="$($SUDO buildah from "$image")"
  $SUDO buildah mount "$ctr"
}

cleanup() {
  set +e
  # All rootful buildah containers in this isolated build job belong to this
  # script. Command substitutions run mount_image in a subshell, so remove the
  # transient containers globally instead of trying to track a shell array.
  $SUDO buildah umount --all >/dev/null 2>&1
  $SUDO buildah rm --all >/dev/null 2>&1
}
trap cleanup EXIT

copy_from_mount() {
  local src="$1" dst="$2"
  # Rootful Buildah mountpoints under /var/lib/containers/storage may not be
  # traversable by the unprivileged GitHub Actions user. Read them through the
  # same privilege boundary that created the mount.
  $SUDO cp -a "$src" "$dst"
}

# V1 still consumes the pinned Sealos utility cache for host helpers only.
# Kubernetes binaries, Kubernetes image list, crictl, containerd and runc no
# longer come from this cache.
log "mounting remaining pinned Sealos utility cache inputs"
MOUNT_CRI="$(mount_image "$CACHE:cri-$ARCH")"
MOUNT_SEALOS="$(mount_image "$CACHE:sealos-v${SEALOS_NO_V}-$ARCH")"

copy_from_mount "$MOUNT_SEALOS/sealos/image-cri-shim" "$ROOTFS/cri/"
copy_from_mount "$MOUNT_SEALOS/sealos/sealctl" "$ROOTFS/opt/"
copy_from_mount "$MOUNT_CRI/cri/conntrack" "$ROOTFS/bin/"
copy_from_mount "$MOUNT_CRI/cri/lsof" "$ROOTFS/opt/"
copy_from_mount "$MOUNT_CRI/cri/registry" "$ROOTFS/cri/"
copy_from_mount "$MOUNT_CRI/cri/libseccomp.tar.gz" "$ROOTFS/cri/"

# The CRI runtime itself is Archinfra-owned and version-pinned.
cp -a "$RUNTIME_BUNDLE" "$ROOTFS/cri/cri-containerd.tar.gz"

[[ -f "$ROOTFS/Kubefile" ]] || die "rootfs Kubefile missing"
[[ "$(head -n1 "$ROOTFS/Kubefile")" == "FROM scratch" ]] \
  || die "rootfs Kubefile must build from scratch"

pause_image="$(grep '/pause:' "$ROOTFS/images/shim/DefaultImageList" | head -n1)"
[[ -n "$pause_image" ]] || die "pause image not found in Kubernetes payload"
ipvs_image="ghcr.io/labring/lvscare:${SEALOS_VERSION}"

# Sealos consumes image list files under images/shim while building a cluster
# image. Keep lvscare explicit so the HA VIP helper is also available offline.
printf '%s\n' "$ipvs_image" > "$ROOTFS/images/shim/LvscareImageList"

log "building cluster image $IMAGE"
cd "$ROOTFS"
$SUDO "$SEALOS" build \
  --label="sealos.io.type=rootfs" \
  --label="sealos.io.version=v1beta1" \
  --label="version=${KUBE_VERSION}" \
  --label="org.archinfra.upstream-runtime=${UPSTREAM_RUNTIME_COMMIT}" \
  --label="org.archinfra.containerd=${CONTAINERD_VERSION}" \
  --label="org.archinfra.runc=${RUNC_VERSION}" \
  --label="org.archinfra.crictl=${CRICTL_VERSION}" \
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
CRICTL_VERSION=${CRICTL_VERSION}
EOF

log "cluster image built: $IMAGE"
