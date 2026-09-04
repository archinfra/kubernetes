#!/bin/bash
# Derived from labring-actions/runtime; Apache-2.0.
cd "$(dirname "$0")" >/dev/null 2>&1 || exit
source common.sh
readonly BIN_DIR=${BIN_DIR:-/usr/bin}
readonly DATA=${1:-/var/lib/registry}
readonly CONFIG=${2:-/etc/registry}
check_service stop registry 2>/dev/null || true
rm -f /etc/systemd/system/registry.service "${BIN_DIR}/registry"
rm -rf "$DATA" "$CONFIG"
rm -f /etc/registry.yml
logger "clean registry success"
