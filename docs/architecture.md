# Architecture

## Responsibility boundary

```text
Kubernetes upstream release
        |
        v
Archinfra version manifest
        |
        +--> Sealos-compatible runtime rootfs
        |      +-- k8s
        |      +-- containerd
        |      +-- local registry
        |
        v
Sealos cluster image
        |
        +--> smoke / E2E validation
        |
        v
apps_kubernetes offline package
```

Sealos is used as the bootstrap/distribution engine. Archinfra owns the version matrix, runtime rootfs, validation, packaging and release policy.

## Why this is not a Sealos fork

Kubernetes patch releases should normally require only a version-manifest change plus validation. We only fork/patch the Sealos Go code if its cluster lifecycle itself blocks a supported Kubernetes version.

## Release gates

A candidate is not promoted until it passes:

1. build reproducibility and checksum generation;
2. single-control-plane init;
3. three-control-plane HA init/join;
4. worker join/reboot;
5. CoreDNS / Service / kube-proxy checks after CNI installation;
6. audit log validation;
7. etcd snapshot/restore;
8. upgrade from the previous approved patch/minor baseline.
