#!/bin/bash
# Derived from labring-actions/runtime; Apache-2.0.
set -e
cd "$(dirname "$0")" >/dev/null 2>&1 || exit
source common.sh
REGISTRY_DOMAIN=${1:-sealos.hub}
REGISTRY_PORT=${2:-5000}
if ! bash init-containerd.sh "$REGISTRY_DOMAIN" "$REGISTRY_PORT"; then
  error "====init containerd failed!===="
fi
