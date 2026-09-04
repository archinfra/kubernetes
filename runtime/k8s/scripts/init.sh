#!/bin/bash
# Derived from labring-actions/runtime; Apache-2.0.
set -e
cd "$(dirname "$0")" >/dev/null 2>&1 || exit
source common.sh
bash init-shim.sh || error "init image-cri-shim failed"
bash init-kube.sh || error "init kubelet failed"
logger "init rootfs success"
