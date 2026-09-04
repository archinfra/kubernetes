#!/bin/bash
# Derived from labring-actions/runtime; Apache-2.0.
set -e
cd "$(dirname "$0")" >/dev/null 2>&1 || exit
source common.sh
storage=${1:-/var/lib/registry}
check_port_inuse
if command_exists docker; then
  error "docker already exists; remove the conflicting Docker runtime before installation"
fi
check_file_exits "$storage"
if ! command_exists apparmor_parser; then
  sed -i 's/disable_apparmor = false/disable_apparmor = true/g' ../etc/config.toml
  warn "AppArmor tools not found; disable_apparmor=true"
fi
logger "runtime preflight success"
