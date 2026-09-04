SHELL := /usr/bin/env bash

VERSION ?= v1.36.4
ARCH ?= amd64
IMAGE ?= localhost/archinfra/kubernetes:$(VERSION)-$(ARCH)

.PHONY: help install-sealos static-check kubernetes-payload runtime-bundle check cluster-image package verify clean

help:
	@echo "Targets:"
	@echo "  install-sealos      install pinned sealos into .cache/bin"
	@echo "  static-check        validate shell/runtime source structure"
	@echo "  kubernetes-payload  fetch and verify Kubernetes + crictl payload"
	@echo "  runtime-bundle      build pinned containerd+runc bundle"
	@echo "  check               validate build host and version inputs"
	@echo "  cluster-image       build local Sealos Kubernetes cluster image"
	@echo "  package             build apps_kubernetes offline delivery archive"
	@echo "  verify              verify generated delivery archive"
	@echo "  clean               remove generated files"

install-sealos:
	VERSION=$(VERSION) ARCH=$(ARCH) ./hack/install-sealos.sh

static-check:
	./hack/static-check.sh

kubernetes-payload:
	VERSION=$(VERSION) ARCH=$(ARCH) ./hack/build-kubernetes-payload.sh

runtime-bundle:
	VERSION=$(VERSION) ARCH=$(ARCH) ./hack/build-runtime-bundle.sh

check:
	VERSION=$(VERSION) ARCH=$(ARCH) ./hack/check-tools.sh

cluster-image:
	VERSION=$(VERSION) ARCH=$(ARCH) IMAGE=$(IMAGE) ./hack/build-cluster-image.sh

package: cluster-image
	VERSION=$(VERSION) ARCH=$(ARCH) IMAGE=$(IMAGE) ./hack/package.sh

verify:
	VERSION=$(VERSION) ARCH=$(ARCH) ./hack/verify-package.sh

clean:
	rm -rf dist .work
