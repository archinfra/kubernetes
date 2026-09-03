#!/usr/bin/env bash
set -euo pipefail

# Kubernetes initialization logic.
# This follows the Sealos runtime/k8s lifecycle pattern.

if command -v kubeadm >/dev/null 2>&1; then
  echo "kubeadm detected: $(kubeadm version -o short || true)"
fi

if command -v kubelet >/dev/null 2>&1; then
  echo "kubelet detected"
fi
