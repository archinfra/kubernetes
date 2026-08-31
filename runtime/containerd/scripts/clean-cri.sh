#!/bin/bash
# Derived from labring-actions/runtime; Apache-2.0.
set -e
cd "$(dirname "$0")" >/dev/null 2>&1 || exit
source common.sh
storage=${1:-/var/lib/containerd}
bash clean-containerd.sh "$storage"
logger "clean containerd cri success"
