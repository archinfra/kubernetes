#!/bin/bash
# Derived from labring-actions/runtime; Apache-2.0.
set -e
cd "$(dirname "$0")" >/dev/null 2>&1 || exit
source common.sh
storage=${1:-/var/lib/containerd}
readonly BIN_DIR=${BIN_DIR:-/usr/bin}
systemctl stop containerd 2>/dev/null || true
systemctl disable containerd 2>/dev/null || true
rm -rf /etc/containerd /etc/systemd/system/containerd.service "$storage" /run/containerd/containerd.sock /var/lib/nerdctl
systemctl daemon-reload
for binary in containerd containerd-stress containerd-shim containerd-shim-runc-v1 containerd-shim-runc-v2 crictl ctr ctd-decoder runc nerdctl crun crun_; do
  rm -f "${BIN_DIR}/${binary}"
done
rm -f /etc/crictl.yaml
rm -rf /opt/containerd /etc/ld.so.conf.d/containerd.conf
ldconfig
logger "clean containerd success"
