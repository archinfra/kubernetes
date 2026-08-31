#!/bin/bash
# Derived from labring-actions/runtime; Apache-2.0.
set -e
cd "$(dirname "$0")" >/dev/null 2>&1 || exit
source common.sh
registry_domain=${1:-sealos.hub}
registry_port=${2:-5000}
readonly BIN_DIR=${BIN_DIR:-/usr/bin}

mkdir -p /opt/containerd
tar -zxf ../cri/libseccomp.tar.gz -C /opt/containerd
echo "/opt/containerd/lib" >/etc/ld.so.conf.d/containerd.conf
ldconfig
mkdir -p /etc/containerd/certs.d/
cp ../etc/containerd.service /etc/systemd/system/
tar -zxf ../cri/cri-containerd.tar.gz --strip-components 2 -C ${BIN_DIR}
chmod a+x $(tar -tf ../cri/cri-containerd.tar.gz | while read -r binary; do echo "${BIN_DIR}/${binary##*/}"; done | xargs)
systemctl enable containerd.service
cp ../etc/config.toml /etc/containerd/config.toml
mkdir -p "/etc/containerd/certs.d/$registry_domain:$registry_port"
cp ../etc/hosts.toml "/etc/containerd/certs.d/$registry_domain:$registry_port/hosts.toml"
systemctl daemon-reload
systemctl restart containerd.service
check_status containerd
logger "init containerd success"
