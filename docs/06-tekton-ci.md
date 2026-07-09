# 06 — Tekton CI Pipeline

This guide walks through the Tekton pipeline that builds and publishes the Polaris app.

## Pipeline overview

```
clone → test → build → update-manifests
```

| Task | Image | Action |
|------|-------|--------|
| `git-clone` | alpine/git | Shallow clone of your repo |
| `run-tests` | python:3.12-slim | `pytest app/test_app.py` |
| `build-push` | kaniko | Build Dockerfile, push to registry |
| `update-manifests` | alpine/git + kustomize | Bump image tag, git push |

## Pipeline definition

Located at `tekton/pipelines/polaris-pipeline.yaml`.

Parameters:

| Param | Description | Example |
|-------|-------------|---------|
| `git-url` | Repository URL | `https://github.com/user/polaris-pipeline.git` |
| `git-revision` | Branch | `main` |
| `image-tag` | New image tag | `v0.1.2` |
| `image-name` | Image name | `polaris-app` |
| `overlay-path` | Kustomize overlay | `deploy/overlays/dev` |

## Run the pipeline

### Easy way (recommended)

```bash
./scripts/run-pipeline.sh v0.1.2
```

### Manual way

Edit `tekton/pipelineruns/polaris-pipeline-run.yaml`:

- Set `git-url` to your repo
- Set `image-tag` to a new version

Apply:

```bash
kubectl apply -f tekton/pipelineruns/polaris-pipeline-run.yaml
```

### Watch progress

```bash
# List runs
kubectl get pipelineruns -n polaris-pipeline

# Watch a specific run
kubectl describe pipelinerun polaris-pipeline-run -n polaris-pipeline

# With Tekton CLI
tkn pipelinerun logs -f -n polaris-pipeline
```

## What each task does

### git-clone

Clones your repo into a shared workspace (PVC). Uses `GIT_TOKEN` secret for private repos.

### run-tests

Installs Flask and pytest, runs `app/test_app.py`. If tests fail, the pipeline stops — no broken image is built.

### build-push

Uses Kaniko (no Docker daemon required) to:

1. Read `app/Dockerfile`
2. Build the image
3. Push to `registry.kube-system.svc.cluster.local:80/polaris-app:TAG`

Kaniko uses `--insecure` because the minikube registry is HTTP-only.

### update-manifests

1. Runs `kustomize edit set image` in `deploy/overlays/dev`
2. Commits the change
3. Pushes to `main`

Argo CD then syncs the new tag.

## Make a change and run CI

1. Edit `app/app.py` — change the greeting message
2. Commit and push to Git
3. Run the pipeline with a new tag:

```bash
./scripts/run-pipeline.sh v0.1.2
```

4. Verify in Argo CD that `polaris-dev` synced
5. Curl the app and see your change

## Pipeline troubleshooting

### Clone fails — authentication

```bash
kubectl create secret generic git-credentials \
  -n polaris-pipeline \
  --from-literal=token=ghp_xxx \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Build fails — registry unreachable

Ensure registry addon is enabled:

```bash
minikube addons enable registry
kubectl get svc -n kube-system registry
```

### update-manifests fails — push rejected

- Ensure `GIT_TOKEN` has `repo` write scope
- Ensure the token user has push access to the repository
- Check logs: `kubectl logs -n polaris-pipeline -l tekton.dev/taskRun=<taskrun-name>`

### Pipeline stuck — PVC pending

minikube needs a default StorageClass:

```bash
kubectl get storageclass
```

The standard minikube driver provides `standard` automatically.

## Next

→ [07-end-to-end-workflow.md](07-end-to-end-workflow.md)
