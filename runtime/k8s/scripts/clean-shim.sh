#!/bin/bash
# Derived from labring-actions/runtime; Apache-2.0.
cd "$(dirname "$0")" >/dev/null 2>&1 || exit
source common.sh
readonly BIN_DIR=${BIN_DIR:-/usr/bin}
systemctl stop image-cri-shim 2>/dev/null || true
systemctl disable image-cri-shim 2>/dev/null || true
rm -f /etc/systemd/system/image-cri-shim.service "${BIN_DIR}/image-cri-shim" /etc/image-cri-shim.yaml
rm -rf /var/lib/image-cri-shim
systemctl daemon-reload
logger "clean shim success"
