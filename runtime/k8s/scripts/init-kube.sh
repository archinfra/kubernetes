#!/bin/bash
# Derived from labring-actions/runtime; Apache-2.0.
set -e
cd "$(dirname "$0")" >/dev/null 2>&1 || exit
readonly BIN_DIR=${BIN_DIR:-/usr/bin}
source common.sh

grep -q '127.0.0.1.*localhost' /etc/hosts || echo '127.0.0.1 localhost' >>/etc/hosts
grep -q '::1.*localhost' /etc/hosts || echo '::1 localhost' >>/etc/hosts
cp -a ../scripts/kubelet-pre-start.sh ../scripts/kubelet-post-stop.sh ${BIN_DIR}/
disable_firewalld
cat ../etc/sysctl.d/*.conf | sort -u | grep -v '^$' | while read -r str; do echo "$str # archinfra"; done >>/etc/sysctl.conf
bash ${BIN_DIR}/kubelet-pre-start.sh

begin='### archinfra kubernetes begin ###'
end='### archinfra kubernetes end ###'
if ! grep -qF "$begin" /etc/security/limits.conf; then
  { echo "$begin"; cat ../etc/limits.d/*.conf; echo "$end"; } >>/etc/security/limits.conf
fi

cp -a ../bin/* ${BIN_DIR}/
logger "pull pause image ${registryDomain}:${registryPort}/${sandboxImage}"
crictl pull "${registryDomain}:${registryPort}/${sandboxImage}"
mkdir -p /etc/systemd/system
cp ../etc/kubelet.service /etc/systemd/system/
cp -a ../etc/systemd/system/. /etc/systemd/system/
systemctl daemon-reload
mkdir -p /var/lib/kubelet
systemctl enable kubelet
logger "init kubelet success"
