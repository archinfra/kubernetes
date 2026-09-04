#!/usr/bin/env bash
set -euo pipefail

repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

normalize_arch() {
  case "$1" in
    amd64|x86_64) echo amd64 ;;
    arm64|aarch64) echo arm64 ;;
    *) die "unsupported architecture: $1" ;;
  esac
}

load_version() {
  local root version file
  root="$(repo_root)"
  version="${VERSION:-v1.36.4}"
  [[ "$version" == v* ]] || version="v${version}"
  file="$root/versions/${version}.env"
  [[ -f "$file" ]] || die "version file not found: $file"
  # shellcheck disable=SC1090
  source "$file"
  export VERSION="$version"
}

sealos_bin() {
  local root
  root="$(repo_root)"
  if [[ -x "$root/.cache/bin/sealos" ]]; then
    echo "$root/.cache/bin/sealos"
  elif command -v sealos >/dev/null 2>&1; then
    command -v sealos
  else
    die "sealos not found; run make install-sealos"
  fi
}

sha256_file() {
  sha256sum "$1" | awk '{print $1}'
}
