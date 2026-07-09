# 04 — Install Components

Install Tekton Pipelines and Argo CD on your minikube cluster.

## Install everything at once

```bash
./scripts/setup.sh all
```

Or install components individually as described below.

## Tekton Pipelines

```bash
./scripts/install-tekton.sh
# or
./scripts/setup.sh tekton
```

This applies the official Tekton release manifest:

```
https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
```

### Verify Tekton

```bash
kubectl get pods -n tekton-pipelines
```

Expected pods:

- `tekton-pipelines-controller`
- `tekton-pipelines-webhook`
- `tekton-events-controller`

### Install Tekton CLI (optional)

```bash
brew install tektoncd-cli
tkn version
```

## Apply Tekton lab resources

```bash
./scripts/setup.sh tekton-resources
```

This creates:

| Resource | Purpose |
|----------|---------|
| `polaris-pipeline` namespace | Isolates CI workloads |
| `polaris-pipeline` ServiceAccount | Identity for pipeline runs |
| `git-clone` Task | Clone repository |
| `run-tests` Task | Run pytest |
| `build-push` Task | Kaniko build + push |
| `update-manifests` Task | Bump image tag in Git |
| `polaris-pipeline` Pipeline | Chains all tasks |

### Git credentials secret

For Tekton to push manifest updates:

```bash
kubectl create secret generic git-credentials \
  -n polaris-pipeline \
  --from-literal=token=YOUR_GITHUB_PAT
```

Or set `GIT_TOKEN` in `config/lab.env` and run `tekton-resources` again.

## Argo CD

```bash
./scripts/install-argocd.sh
# or
./scripts/setup.sh argocd
```

### Verify Argo CD

```bash
kubectl get pods -n argocd
```

All pods should be `Running`. Initial startup can take 2–3 minutes.

### Get admin password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

### Access the UI

```bash
./scripts/port-forward.sh argocd
```

Open https://localhost:8080

- Username: `admin`
- Password: (from command above)

Accept the self-signed certificate warning in your browser.

### Install Argo CD CLI (optional)

```bash
brew install argocd
argocd login localhost:8080 --username admin --password <password> --insecure
```

## Register the Argo CD Application

```bash
./scripts/setup.sh argocd-app
```

This applies `argocd/applications/polaris-dev.yaml` with your `GIT_REPO_URL` substituted in.

### Verify the Application

```bash
kubectl get applications -n argocd
argocd app get polaris-dev   # if CLI installed
```

In the UI you should see `polaris-dev` with sync status `Synced` and health `Healthy`.

## Next

→ [05-argocd-gitops.md](05-argocd-gitops.md)
