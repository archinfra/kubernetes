# archinfra/kubernetes

Archinfra 自维护的 Kubernetes 发行与交付仓库。

目标不是 fork Kubernetes，也不是把 Sealos 平台完整搬进来，而是维护一条稳定、可复现、可离线交付的 Kubernetes 基线：

```text
Kubernetes official release + cri-tools official release
  -> verified Kubernetes payload
containerd official release + runc official release
  -> verified CRI runtime bundle
runtime source
  -> Sealos-compatible rootfs
  -> Sealos cluster image
  -> apps_kubernetes offline delivery package
```

## V1 baseline

- Kubernetes: `v1.36.4`
- Sealos: `v5.1.1`
- containerd: `v2.3.3`
- runc: `v1.4.3`
- crictl: `v1.36.0`
- Architectures: `amd64` first, `arm64` prepared
- Host OS target: Ubuntu 22.04 / 24.04
- CNI / CSI / Ingress are deliberately outside the base image and will live under `addons/`

Kubernetes binaries are downloaded directly from `dl.k8s.io`, verified against the Kubernetes-published SHA256, and the control-plane image list is rendered by the exact-version kubeadm. containerd, runc and crictl use explicit checksums pinned in `versions/`.

## Repository layout

```text
.
├── runtime/                 # vendored/adapted Sealos-compatible rootfs source
│   ├── k8s/
│   ├── containerd/
│   └── registry/
├── versions/                # immutable release inputs + checksums
├── hack/                    # fetch / build / package / verify scripts
├── packaging/               # files copied into apps_kubernetes
├── configs/                 # install examples and policy
├── docs/
└── dist/                    # generated, never committed
```

## Build

```bash
make install-sealos VERSION=v1.36.4 ARCH=amd64
make static-check
make kubernetes-payload VERSION=v1.36.4 ARCH=amd64
make runtime-bundle VERSION=v1.36.4 ARCH=amd64
make check VERSION=v1.36.4 ARCH=amd64
make cluster-image VERSION=v1.36.4 ARCH=amd64
make package VERSION=v1.36.4 ARCH=amd64
make verify VERSION=v1.36.4 ARCH=amd64
```

Default local cluster-image tag:

```text
localhost/archinfra/kubernetes:v1.36.4-amd64
```

Final delivery artifact:

```text
dist/apps_kubernetes-v1.36.4-linux-amd64.tar.gz
```

The archive always contains a top-level `apps_kubernetes/` directory:

```text
apps_kubernetes/
├── bin/sealos
├── images/kubernetes-v1.36.4-amd64.tar
├── manifests/release.env
├── manifests/kubernetes-payload.env
├── manifests/runtime.env
├── manifests/provenance.txt
├── configs/
├── scripts/install.sh
├── scripts/verify.sh
└── SHA256SUMS
```

## Offline install

After copying the archive to the first control-plane node:

```bash
tar -xzf apps_kubernetes-v1.36.4-linux-amd64.tar.gz
cd apps_kubernetes
./scripts/verify.sh

./scripts/install.sh \
  --masters 10.0.0.11,10.0.0.12,10.0.0.13 \
  --nodes 10.0.0.21,10.0.0.22 \
  --password 'REDACTED'
```

The base cluster intentionally does not install a CNI. Install the approved CNI immediately after the Kubernetes control plane is ready.

## Ownership boundary

Archinfra owns:

- Kubernetes release baseline and node binaries;
- Kubernetes control-plane image list generation;
- crictl, containerd and runc versions/checksums;
- Sealos-compatible runtime rootfs;
- build, verification and offline packaging;
- production defaults and release gates.

V1 still consumes a pinned `ghcr.io/labring-actions/cache` only for a small set of bootstrap utilities: `conntrack`, `lsof`, registry binary, libseccomp bundle, `image-cri-shim` and `sealctl`. Kubernetes binaries/image list, crictl, containerd and runc no longer come from that cache. Removing the remaining helper cache is the next independence milestone.

## Upstream policy

Parts of `runtime/` are derived from `labring-actions/runtime` and remain Apache-2.0 licensed. See `NOTICE` and `docs/upstream.md`.

We pin the upstream commit used as our baseline in each `versions/*.env`. New upstream changes are reviewed and imported explicitly; production releases never build from an unpinned upstream `main`.
