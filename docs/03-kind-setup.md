# 03 — KIND Cluster Setup

This guide covers creating a **KIND** cluster with a local container registry for the lab.

> Using minikube instead? See [03-minikube-setup.md](03-minikube-setup.md).

## What gets created

| Component | Details |
|-----------|---------|
| KIND cluster | Named `polaris` (configurable) |
| Local registry | Docker container `kind-registry` on `localhost:5000` |
| Metrics server | For `kubectl top` and health checks |

## Quick setup

```bash
./scripts/setup.sh cluster
# or
./scripts/setup.sh kind
```

## Manual setup

### 1. Create cluster + registry

```bash
./scripts/setup-kind.sh
./scripts/configure-manifests.sh
```

### 2. Verify

```bash
kubectl cluster-info --context kind-polaris
kubectl get nodes
docker ps | grep kind-registry
```

## How the registry works

```
Host machine                    KIND cluster
─────────────                   ────────────
docker push                     Pod pulls
localhost:5000  ◄────────────►   localhost:5000/polaris-app:tag
     │                          (containerd mirror → kind-registry)
     ▼
kind-registry container
(on docker 'kind' network)
```

| Action | URL |
|--------|-----|
| Build & push from your laptop | `localhost:5000/polaris-app:tag` |
| Image in Kubernetes manifests | `localhost:5000/polaris-app:tag` |
| Kaniko push from Tekton pod | `host.docker.internal:5000/polaris-app:tag` |

`configure-manifests.sh` sets these URLs in Kustomize and Tekton files based on `config/lab.env`.

## Build and push the initial image

```bash
./scripts/build-initial-image.sh
```

Verify the image is in the registry:

```bash
curl -s http://localhost:5000/v2/_catalog
curl -s http://localhost:5000/v2/polaris-app/tags/list
```

## Useful KIND commands

```bash
# List clusters
kind get clusters

# Delete and recreate
kind delete cluster --name polaris
./scripts/setup-kind.sh

# Load an image directly into nodes (alternative to registry)
kind load docker-image localhost:5000/polaris-app:v0.1.0 --name polaris

# Export kubeconfig
kubectl config use-context kind-polaris
```

## Configuration (config/lab.env)

```bash
CLUSTER_TYPE=kind
KIND_CLUSTER_NAME=polaris
REGISTRY_PORT=5000
REGISTRY_PULL=localhost:5000
REGISTRY_PUSH=host.docker.internal:5000
```

## Next

→ [04-install-components.md](04-install-components.md)
