#!/bin/bash
# Derived from labring-actions/runtime; Apache-2.0.

timestamp() { date +"%Y-%m-%d %T"; }
error() { echo -e "\033[31m ERROR [$(timestamp)] >> $* \033[0m"; exit 1; }
logger() { echo -e "\033[36m INFO [$(timestamp)] >> $* \033[0m"; }
warn() { echo -e "\033[33m WARN [$(timestamp)] >> $* \033[0m"; }

check_service() {
  local action=$1; shift
  systemctl daemon-reload
  case "$action" in
    start) systemctl enable "$@" ;;
    stop) systemctl disable "$@" ;;
    *) error "service action must be start or stop" ;;
  esac
  systemctl "$action" "$@"
}

check_status() {
  for unit; do
    systemctl is-active --quiet "$unit" || error "$unit is not running"
    logger "$unit is running"
  done
}

get_distribution() {
  if [[ -r /etc/os-release ]]; then . /etc/os-release; echo "$ID"; fi
}

disable_firewalld() {
  local dist
  dist="$(get_distribution | tr '[:upper:]' '[:lower:]')"
  case "$dist" in
    ubuntu|deepin|debian|raspbian) command -v ufw >/dev/null 2>&1 && ufw disable || true ;;
    *) systemctl stop firewalld 2>/dev/null || true; systemctl disable firewalld 2>/dev/null || true ;;
  esac
}

command_exists() { command -v "$@" >/dev/null 2>&1; }
check_file_exits() { for f; do [[ -e "$f" ]] && error "machine is not clean: $f exists"; done; }

check_port_inuse() {
  readonly BIN_DIR=${BIN_DIR:-/usr/bin}
  if ! command_exists lsof; then cp -au ../opt/lsof "${BIN_DIR}/lsof"; fi
  for port in {10249..10259} {5050..5054}; do
    if lsof -i :"${port}" >/dev/null 2>&1; then error "port ${port} is already in use"; fi
  done
}
