# 07 — End-to-End Workflow

Complete walkthrough: code change → CI → Git update → CD → running app.

## Scenario

You will change the app's greeting message, run the Tekton pipeline, and watch Argo CD deploy the update.

## Step 1 — Initial state

Confirm everything is running:

```bash
./scripts/setup.sh verify
kubectl get applications -n argocd
kubectl get pods -n polaris-dev
```

Access the app:

```bash
./scripts/port-forward.sh app
curl http://localhost:8888
```

## Step 2 — Make a code change

Edit `app/app.py`:

```python
"message": "Hello from Polaris GitOps lab — version 2!",
```

Run tests locally (optional):

```bash
cd app
pip install flask pytest
python -m pytest -v test_app.py
```

## Step 3 — Commit and push

```bash
git add app/app.py
git commit -m "feat: update greeting message"
git push origin main
```

## Step 4 — Run Tekton CI

Pick a new image tag (must differ from current):

```bash
./scripts/run-pipeline.sh v0.2.0
```

Watch the pipeline:

```bash
kubectl get pipelineruns -n polaris-pipeline -w
```

Expected task order: `clone` → `test` → `build` → `update-manifests` — all `Succeeded`.

## Step 5 — Verify Git was updated

Tekton should have committed a manifest change:

```bash
git pull origin main
git log --oneline -3
```

You should see a commit like:

```
ci: bump polaris-app to v0.2.0
```

Check the diff:

```bash
git show HEAD -- deploy/overlays/dev/kustomization.yaml
```

## Step 6 — Watch Argo CD sync

Open Argo CD UI:

```bash
./scripts/port-forward.sh argocd
```

Or via CLI:

```bash
kubectl get application polaris-dev -n argocd -w
```

Status should transition to `Synced` / `Healthy`.

## Step 7 — Confirm the new version is live

```bash
./scripts/port-forward.sh app
curl http://localhost:8888
```

You should see the updated message.

Check which image is running:

```bash
kubectl get deployment polaris-app -n polaris-dev \
  -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
```

Expected: `registry.kube-system.svc.cluster.local:80/polaris-app:v0.2.0`

## The full loop (diagram)

```
You edit app.py
       │
       ▼
git push ──────────────────────────────────────────────┐
       │                                                │
       ▼                                                │
Tekton PipelineRun                                      │
  ├─ clone (gets your code change)                      │
  ├─ test (pytest passes)                               │
  ├─ build (new image v0.2.0 → registry)              │
  └─ update-manifests (commit tag bump) ──► Git ◄──────┘
                                              │
                                              ▼
                                         Argo CD sync
                                              │
                                              ▼
                                    New pods with v0.2.0
```

## Rollback exercise

To roll back a bad deploy:

```bash
# Revert the manifest commit
git revert HEAD
git push origin main

# Argo CD syncs back to the previous image tag
```

Or in Argo CD UI: **History and rollback** → select previous revision → **Rollback**.

## What you have now

You have a working GitOps platform on minikube:

- ✅ Sample app with tests
- ✅ Kustomize-based manifests
- ✅ Tekton CI pipeline
- ✅ Argo CD automated deployment
- ✅ Local container registry
- ✅ Full audit trail in Git

## Next

→ [08-troubleshooting.md](08-troubleshooting.md)
