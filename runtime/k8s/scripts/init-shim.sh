#!/bin/bash
# Derived from labring-actions/runtime; Apache-2.0.
set -e
cd "$(dirname "$0")" >/dev/null 2>&1 || exit
source common.sh
readonly BIN_DIR=${BIN_DIR:-/usr/bin}
cp -f ../etc/image-cri-shim.service /etc/systemd/system/
cp -f ../etc/image-cri-shim.yaml /etc/
cp -f ../cri/image-cri-shim "${BIN_DIR}/"
[[ -f ../etc/crictl.yaml ]] && cp -f ../etc/crictl.yaml /etc/
systemctl enable image-cri-shim.service
systemctl daemon-reload
systemctl restart image-cri-shim.service
check_status image-cri-shim
logger "init shim success"
