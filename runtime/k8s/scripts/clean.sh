#!/bin/bash
# Derived from labring-actions/runtime; Apache-2.0.
cd "$(dirname "$0")" >/dev/null 2>&1 || exit
source common.sh
bash clean-kube.sh
bash clean-shim.sh
logger "clean rootfs success"
