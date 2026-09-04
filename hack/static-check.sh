#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

status=0
while IFS= read -r -d '' f; do
  if ! bash -n "$f"; then
    echo "bash syntax failed: $f" >&2
    status=1
  fi
done < <(find "$ROOT/hack" "$ROOT/packaging" "$ROOT/runtime" -type f -name '*.sh' -print0)

required=(
  LICENSE
  NOTICE
  runtime/UPSTREAM
  runtime/containerd/Kubefile
  runtime/containerd/etc/config.toml.tmpl
  runtime/containerd/scripts/init-containerd.sh
  runtime/k8s/scripts/init.sh
  runtime/k8s/scripts/init-kube.sh
  runtime/k8s/etc/kubelet.service.tmpl
  runtime/k8s/statics/audit-policy.yml
  runtime/registry/scripts/init-registry.sh
  versions/v1.36.4.env
  hack/build-kubernetes-payload.sh
  hack/build-runtime-bundle.sh
)
for f in "${required[@]}"; do
  [[ -f "$ROOT/$f" ]] || { echo "missing required file: $f" >&2; status=1; }
done

grep -q '^KUBE_VERSION=v1.36.4$' "$ROOT/versions/v1.36.4.env" || status=1
grep -q '^CONTAINERD_VERSION=v2.3.3$' "$ROOT/versions/v1.36.4.env" || status=1
grep -q '^RUNC_VERSION=v1.4.3$' "$ROOT/versions/v1.36.4.env" || status=1
grep -q '^CRICTL_VERSION=v1.36.0$' "$ROOT/versions/v1.36.4.env" || status=1
grep -q '^commit=ac453ddb30234dbec93005e97c08a8b7b55dbba9$' "$ROOT/runtime/UPSTREAM" || status=1
grep -q '^version = 3$' "$ROOT/runtime/containerd/etc/config.toml.tmpl" || { echo 'containerd 2.x config must use schema version 3' >&2; status=1; }
grep -q 'io.containerd.cri.v1.runtime' "$ROOT/runtime/containerd/etc/config.toml.tmpl" || { echo 'containerd 2.x CRI runtime plugin missing' >&2; status=1; }
grep -q 'io.containerd.cri.v1.images' "$ROOT/runtime/containerd/etc/config.toml.tmpl" || { echo 'containerd 2.x CRI images plugin missing' >&2; status=1; }

exit "$status"
