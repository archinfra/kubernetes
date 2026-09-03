#!/usr/bin/env bash
set -euo pipefail

# Archinfra Kubernetes cluster image bootstrap entrypoint.
# This file will be extended from the upstream Sealos runtime/k8s flow.

ROOTFS=/rootfs

if [ -x "${ROOTFS}/scripts/init-kube.sh" ]; then
  exec "${ROOTFS}/scripts/init-kube.sh" "$@"
fi

echo "Archinfra Kubernetes image bootstrap placeholder"
