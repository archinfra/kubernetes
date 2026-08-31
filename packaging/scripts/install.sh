#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/manifests/release.env"
SEALOS="$ROOT/bin/sealos"

masters=""
nodes=""
password=""
port="22"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install.sh --masters <ip,ip,...> [--nodes <ip,ip,...>] [--password <password>] [--port 22]

For passwordless SSH, omit --password and let Sealos use the host SSH configuration/key.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --masters) masters="$2"; shift 2 ;;
    --nodes) nodes="$2"; shift 2 ;;
    --password) password="$2"; shift 2 ;;
    --port) port="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$masters" ]] || { echo '--masters is required' >&2; exit 2; }

"$ROOT/scripts/verify.sh"

echo "Loading offline cluster image..."
sudo "$SEALOS" load -i "$ROOT/$CLUSTER_IMAGE_ARCHIVE"

cmd=(sudo "$SEALOS" run "$CLUSTER_IMAGE" --masters "$masters" --port "$port")
[[ -n "$nodes" ]] && cmd+=(--nodes "$nodes")
[[ -n "$password" ]] && cmd+=(-p "$password")

printf 'Executing:'
printf ' %q' "${cmd[@]}"
printf '\n'
"${cmd[@]}"

cat <<EOF
Kubernetes base installation completed.
Next required step: install the approved CNI before treating the cluster as ready.
EOF
