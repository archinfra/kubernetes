#!/bin/bash
# Derived from labring-actions/runtime; Apache-2.0.
set -e
cd "$(dirname "$0")" >/dev/null 2>&1 || exit
source common.sh
readonly DATA=${1:-/var/lib/registry}
readonly CONFIG=${2:-/etc/registry}
readonly BIN_DIR=${BIN_DIR:-/usr/bin}
mkdir -p "$DATA" "$CONFIG"
cp -a ../etc/registry.service /etc/systemd/system/
cp -a ../cri/registry "${BIN_DIR}/registry"
cp -a ../etc/registry_config.yml "$CONFIG/registry_config.yml"
[[ -f ../etc/registry_htpasswd ]] && cp -a ../etc/registry_htpasswd "$CONFIG/registry_htpasswd"
if [[ -s /etc/selinux/config ]] && grep -q 'SELINUX=enforcing' /etc/selinux/config; then
  sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
  setenforce 0 || true
fi
check_service start registry
check_status registry
logger "init registry success"
