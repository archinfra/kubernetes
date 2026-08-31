#!/bin/bash
# Derived from labring-actions/runtime; Apache-2.0.
cd "$(dirname "$0")" >/dev/null 2>&1 || exit
source common.sh
readonly BIN_DIR=${BIN_DIR:-/usr/bin}
systemctl stop kubelet 2>/dev/null || true
systemctl disable kubelet 2>/dev/null || true
for f in conntrack kubelet-pre-start.sh kubelet-post-stop.sh kubeadm kubectl kubelet; do rm -f "${BIN_DIR}/${f}"; done
sed -i '/ # archinfra$/d' /etc/sysctl.conf 2>/dev/null || true
rm -f /etc/systemd/system/kubelet.service
rm -rf /etc/systemd/system/kubelet.service.d /var/lib/kubelet/
systemctl daemon-reload
logger "clean kubelet success"
