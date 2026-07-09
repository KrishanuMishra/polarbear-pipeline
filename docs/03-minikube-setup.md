# 03 — Minikube Setup

This guide covers starting minikube and enabling the addons required for the lab.

## Start minikube

The setup script handles this, or run manually:

```bash
minikube start \
  --cpus=4 \
  --memory=6144 \
  --driver=docker

kubectl config use-context minikube
```

### Why these settings?

- **4 CPUs / 6 GB RAM** — Tekton, Argo CD, and your app run concurrently
- **docker driver** — best experience on macOS; integrates with Docker Desktop

## Enable addons

```bash
minikube addons enable registry
minikube addons enable metrics-server
minikube addons enable ingress
```

### Registry addon

The registry lets you push images without Docker Hub or another external registry.

| From | Registry URL |
|------|--------------|
| Your laptop (docker push) | `localhost:5000` |
| Inside the cluster | `registry.kube-system.svc.cluster.local:80` |

Verify the registry is running:

```bash
kubectl get pods -n kube-system -l kubernetes.io/minikube-addons=registry
```

### Metrics server

Required for `kubectl top` and some health checks. Argo CD uses it indirectly for resource metrics.

### Ingress (optional for this lab)

Enabled for future exercises. The lab uses `NodePort` + port-forward for simplicity.

## Build and push the initial image

Before Argo CD can deploy, an image must exist in the registry:

```bash
./scripts/build-initial-image.sh
```

Under the hood:

1. Points Docker at minikube's daemon: `eval $(minikube docker-env)`
2. Builds `app/Dockerfile`
3. Tags as `localhost:5000/polaris-app:v0.1.0`
4. Pushes to the minikube registry

## Verify the cluster

```bash
kubectl get nodes
kubectl get pods -A
minikube status
```

Expected output for `minikube status`:

```
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
```

## Useful minikube commands

```bash
# Open Kubernetes dashboard
minikube dashboard

# SSH into the minikube node
minikube ssh

# Stop cluster (preserves state)
minikube stop

# Delete cluster
minikube delete
```

## Next

→ [04-install-components.md](04-install-components.md)
