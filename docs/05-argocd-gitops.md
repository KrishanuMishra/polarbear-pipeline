# 05 — Argo CD GitOps

This guide explains how Argo CD deploys the Polaris app from Git.

## The Application manifest

```yaml
# argocd/applications/polaris-dev.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: polaris-dev
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/YOUR_USER/polaris-pipeline.git
    targetRevision: main
    path: deploy/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: polaris-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Key fields

| Field | Meaning |
|-------|---------|
| `source.repoURL` | Git repo Argo CD watches |
| `source.path` | Kustomize overlay directory |
| `destination.namespace` | Where resources are deployed |
| `syncPolicy.automated` | Auto-sync on Git changes |
| `prune: true` | Delete resources removed from Git |
| `selfHeal: true` | Revert manual cluster changes |

## What Argo CD deploys

Preview locally with kustomize:

```bash
kubectl kustomize deploy/overlays/dev
```

Deployed resources:

- `Namespace/polaris-dev`
- `Deployment/polaris-app`
- `Service/polaris-app` (NodePort)

## Sync behavior

### Automated sync

When Tekton pushes a new image tag to Git, Argo CD:

1. Detects the commit (polls every ~3 minutes by default)
2. Runs `kustomize build deploy/overlays/dev`
3. Applies the diff to the cluster
4. Waits for Deployment rollout

### Manual sync

In the UI: Application → **Sync** button.

CLI:

```bash
argocd app sync polaris-dev
```

## Verify the deployment

```bash
kubectl get all -n polaris-dev
kubectl describe deployment polaris-app -n polaris-dev
```

### Access the app

```bash
./scripts/port-forward.sh app
curl http://localhost:8888
```

Expected response:

```json
{
  "service": "polaris-app",
  "version": "dev",
  "status": "ok",
  "message": "Hello from Polaris GitOps lab!"
}
```

## Observing GitOps in action

### Test self-heal

1. Scale the deployment manually:

```bash
kubectl scale deployment polaris-app -n polaris-dev --replicas=3
```

2. Wait ~30 seconds. Argo CD reverts to `replicas: 1` (defined in Git).

### Test drift detection

```bash
kubectl edit deployment polaris-app -n polaris-dev
# Change an env var
```

Argo CD UI shows `OutOfSync`. With `selfHeal: true`, it reverts automatically.

## Sync waves and hooks (future)

For production you might add:

- Pre-sync hooks (migrations)
- Sync waves (deploy DB before app)
- Manual approval for prod Applications

## Adding another environment

Copy the dev overlay:

```bash
cp -r deploy/overlays/dev deploy/overlays/staging
```

Create a new Argo CD Application pointing at `deploy/overlays/staging`. Use Tekton parameters to target different overlays per pipeline.

## Next

→ [06-tekton-ci.md](06-tekton-ci.md)
