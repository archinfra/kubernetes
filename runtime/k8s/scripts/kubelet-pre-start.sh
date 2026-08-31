#!/bin/bash
# Derived from labring-actions/runtime; Apache-2.0.
set -e
for mod in bridge ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh br_netfilter; do modprobe "$mod" || true; done
modprobe nf_conntrack >/dev/null 2>&1 || modprobe nf_conntrack_ipv4 || true
sysctl --system
swapoff --all || true
if grep -q 'SELINUX=enforcing' /etc/selinux/config 2>/dev/null; then
  sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
  setenforce 0 || true
fi
