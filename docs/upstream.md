# Sealos upstream tracking

Runtime compatibility code is derived from:

- Repository: `https://github.com/labring-actions/runtime`
- Initial pin: `ac453ddb30234dbec93005e97c08a8b7b55dbba9`
- License: Apache-2.0

The upstream repository already carries a Kubernetes 1.36 version lane and added higher-Kubernetes build fixes in 2026. Archinfra imports only the runtime pieces needed for the Kubernetes + containerd distribution.

## Update procedure

1. Review commits since the currently pinned `UPSTREAM_RUNTIME_COMMIT`.
2. Import relevant `k8s/`, `containerd/`, `registry/` or build logic changes.
3. Retain upstream copyright/license headers on derived files.
4. Update `UPSTREAM_RUNTIME_COMMIT` only in a PR that passes the release gates.

Do not build production packages from upstream `main` dynamically.
