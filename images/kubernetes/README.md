# Archinfra Kubernetes Cluster Image

Build target:

```
archinfra/kubernetes:v1.36.4
```

Source inputs:

- Kubernetes binaries
- kubeadm image list
- Sealos cluster image runtime
- Archinfra release manifest

Build flow:

```
versions/v1.36.4
        |
        v
kubeadm/kubelet/kubectl download
        |
        v
sealos build
        |
        v
kubernetes cluster image
```
