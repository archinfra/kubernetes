# Installation configuration

V1 intentionally uses Sealos CLI arguments for bootstrap because they are easy to audit in an offline delivery package.

Planned configuration surfaces:

- HA control-plane endpoint / VIP
- SSH user/key/password policy
- kubeadm ClusterConfiguration and InitConfiguration overrides
- API server audit flags and audit log retention
- certificate policy
- registry mirror / private CA
- containerd data-root

CNI, CSI, Ingress and observability are addons and are not bundled into the Kubernetes base cluster image.
