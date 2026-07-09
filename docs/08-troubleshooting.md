# 08 — Troubleshooting

Common issues and how to fix them.

## minikube

### `minikube start` fails

```bash
# Reset and retry
minikube delete
minikube start --cpus=4 --memory=6144 --driver=docker
```

### Not enough memory

Symptoms: pods stuck in `Pending`, OOMKilled.

Fix: increase memory or stop unused clusters:

```bash
minikube stop -p other-profile
minikube start --memory=8192
```

## Registry

### Image pull errors: `ImagePullBackOff`

Check the image exists in the registry:

```bash
# List images in minikube registry (from host)
curl http://localhost:5000/v2/_catalog
curl http://localhost:5000/v2/polaris-app/tags/list
```

Rebuild and push:

```bash
./scripts/build-initial-image.sh
```

### Wrong image URL in manifests

| Context | Correct format |
|---------|----------------|
| Host docker push | `localhost:5000/polaris-app:tag` |
| Kubernetes manifests | `registry.kube-system.svc.cluster.local:80/polaris-app:tag` |

## Argo CD

### Application stuck `Progressing` or `Degraded`

```bash
kubectl describe application polaris-dev -n argocd
kubectl get pods -n polaris-dev
kubectl logs -n polaris-dev -l app=polaris-app
```

### Application `Unknown` — repo not reachable

- Verify `GIT_REPO_URL` is correct and publicly accessible (or add repo credentials in Argo CD)
- For private repos: Argo CD UI → Settings → Repositories → Connect repo

### Sync fails — `namespace auto-create` issues

Ensure `CreateNamespace=true` is in syncOptions (already set in our Application).

### Cannot log in to UI

Reset admin password:

```bash
argocd admin initial-password -n argocd
# or patch the secret if needed
```

## Tekton

### PipelineRun fails at clone

```bash
kubectl describe pipelinerun -n polaris-pipeline <run-name>
kubectl logs -n polaris-pipeline <pod-name> -c step-clone
```

Fixes:
- Check `git-url` is correct
- Add `GIT_TOKEN` for private repos

### PipelineRun fails at build (Kaniko)

```bash
kubectl logs -n polaris-pipeline <pod-name> -c step-build-and-push
```

Fixes:
- Enable registry addon: `minikube addons enable registry`
- Verify `registry.kube-system.svc.cluster.local:80` is reachable from pods

### PipelineRun fails at update-manifests

```bash
kubectl logs -n polaris-pipeline <pod-name> -c step-update-and-push
```

Fixes:
- `GIT_TOKEN` needs `repo` scope with write access
- Branch protection may block bot pushes — allow the token user or use a bypass rule

### PVC stuck in Pending

```bash
kubectl get pvc -n polaris-pipeline
kubectl get storageclass
```

Enable default storage class if missing:

```bash
kubectl patch storageclass standard \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

## Application

### App returns connection refused

```bash
kubectl get pods -n polaris-dev
kubectl port-forward svc/polaris-app -n polaris-dev 8888:80
```

### Health check failing

```bash
kubectl logs -n polaris-dev -l app=polaris-app
kubectl describe pod -n polaris-dev -l app=polaris-app
```

## Useful debug commands

```bash
# Everything at a glance
./scripts/setup.sh verify

# All events (recent errors)
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Argo CD application details
kubectl get application polaris-dev -n argocd -o yaml

# Tekton task runs
kubectl get taskruns -n polaris-pipeline

# What's in the registry
curl -s http://localhost:5000/v2/_catalog | python3 -m json.tool
```

## Clean slate

Start completely fresh:

```bash
minikube delete
rm -f config/lab.env   # keep your tokens safe — back up first
./scripts/setup.sh all
```

## Getting help

- [Tekton docs](https://tekton.dev/docs/)
- [Argo CD docs](https://argo-cd.readthedocs.io/)
- [minikube docs](https://minikube.sigs.k8s.io/docs/)
- [Kustomize docs](https://kustomize.io/)
