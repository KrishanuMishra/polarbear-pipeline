# Polaris Pipeline — Tekton + ArgoCD GitOps Lab

A hands-on lab for learning GitOps on a local **KIND** or **minikube** cluster. This repo contains:

- A sample **Python Flask** application
- **Kustomize** manifests for Kubernetes deployment
- **Tekton** CI pipelines (clone → test → build → push → update Git)
- **Argo CD** CD configuration (sync manifests from Git to cluster)
- Setup scripts and step-by-step documentation

## Architecture

```
Developer push
      │
      ▼
┌─────────────┐     build image      ┌──────────────────┐
│   Tekton    │ ──────────────────►  │ Minikube registry │
│  (CI/CD)    │                      │ localhost:5000    │
└──────┬──────┘                      └──────────────────┘
       │ update image tag in Git
       ▼
┌─────────────┐     watch & sync     ┌──────────────────┐
│  Git repo   │ ◄──────────────────  │     Argo CD      │
│  (source    │                      │  (GitOps engine) │
│   of truth) │ ──────────────────►  └────────┬─────────┘
└─────────────┘                               │
                                              ▼
                                    ┌──────────────────┐
                                    │  polaris-dev ns  │
                                    │  (running app)   │
                                    └──────────────────┘
```

**Key GitOps rule:** Tekton never runs `kubectl apply` to deploy your app. It only updates Git. Argo CD is the only component that applies manifests to the cluster.

## Quick start

### Prerequisites

| Tool | Purpose |
|------|---------|
| [minikube](https://minikube.sigs.k8s.io/docs/start/) or [KIND](https://kind.sigs.k8s.io/) | Local Kubernetes cluster |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Kubernetes CLI |
| [docker](https://docs.docker.com/get-docker/) | Build container images |
| [git](https://git-scm.com/) | Version control |
| GitHub (or GitLab) account | Remote Git repo for Argo CD |

See [docs/01-prerequisites.md](docs/01-prerequisites.md) for version checks and install links.

### 1. Push this repo to a remote

Argo CD and Tekton both need a Git remote URL.

```bash
cd polaris-pipeline
git init
git add .
git commit -m "Initial Polaris GitOps lab"
git branch -M main
git remote add origin https://github.com/YOUR_USER/polaris-pipeline.git
git push -u origin main
```

### 2. Configure the lab

```bash
cp config/lab.env.example config/lab.env
```

Edit `config/lab.env`:

```bash
CLUSTER_TYPE=kind
GIT_REPO_URL=https://github.com/YOUR_USER/polaris-pipeline.git
GIT_BRANCH=main
IMAGE_TAG=v0.1.0

# Required for Tekton to push manifest updates — see docs/09-github-token.md
GIT_TOKEN=github_pat_your_token_here
```

### 3. Bootstrap everything

```bash
./scripts/setup.sh all
```

This will:

1. Start minikube with registry, ingress, and metrics-server
2. Install Tekton Pipelines
3. Install Argo CD
4. Build and push the initial `v0.1.0` image
5. Apply Tekton tasks and pipeline
6. Register the Argo CD Application

### 4. Access the UIs

```bash
# Argo CD (https://localhost:8080, user: admin)
./scripts/port-forward.sh argocd

# Polaris app (http://localhost:8888)
./scripts/port-forward.sh app
```

Argo CD admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

### 5. Run the CI pipeline

Make a code change, commit, and push. Then run Tekton:

```bash
./scripts/run-pipeline.sh v0.1.1
```

Watch Argo CD sync the new image tag automatically.

## Repository layout

```
polaris-pipeline/
├── app/                    # Sample Python Flask application
│   ├── app.py
│   ├── Dockerfile
│   ├── requirements.txt
│   └── test_app.py
├── deploy/                 # Kubernetes manifests (Kustomize)
│   ├── base/
│   └── overlays/dev/
├── tekton/                 # CI pipeline definitions
│   ├── tasks/
│   ├── pipelines/
│   └── pipelineruns/
├── argocd/                 # Argo CD Application manifests
│   └── applications/
├── scripts/                # Bootstrap and helper scripts
├── config/                 # Local lab configuration
└── docs/                   # Detailed lab documentation
```

## Documentation

| Guide | Description |
|-------|-------------|
| [01-prerequisites.md](docs/01-prerequisites.md) | Tools, versions, and Git setup |
| [02-architecture.md](docs/02-architecture.md) | How Tekton and Argo CD fit together |
| [03-kind-setup.md](docs/03-kind-setup.md) | KIND cluster and registry (default) |
| [03-minikube-setup.md](docs/03-minikube-setup.md) | minikube cluster and registry |
| [04-install-components.md](docs/04-install-components.md) | Installing Tekton and Argo CD |
| [05-argocd-gitops.md](docs/05-argocd-gitops.md) | Deploying with Argo CD |
| [06-tekton-ci.md](docs/06-tekton-ci.md) | Running the CI pipeline |
| [07-end-to-end-workflow.md](docs/07-end-to-end-workflow.md) | Full change → deploy walkthrough |
| [08-troubleshooting.md](docs/08-troubleshooting.md) | Common issues and fixes |
| [09-github-token.md](docs/09-github-token.md) | Create and configure GIT_TOKEN |

## Individual setup commands

```bash
./scripts/setup.sh cluster           # KIND or minikube (per config/lab.env)
./scripts/setup.sh kind              # KIND cluster + registry
./scripts/setup.sh tekton            # Install Tekton only
./scripts/setup.sh argocd            # Install Argo CD only
./scripts/setup.sh registry          # Build initial image
./scripts/setup.sh tekton-resources  # Apply Tekton CRDs
./scripts/setup.sh argocd-app        # Register Argo CD app
./scripts/setup.sh verify            # Check status
```

## What you will learn

- GitOps principles: Git as the single source of truth
- Kustomize overlays for environment-specific config
- Tekton Tasks, Pipelines, and PipelineRuns on Kubernetes
- Argo CD Applications with automated sync
- Building images with Kaniko inside the cluster
- Using minikube's built-in container registry
- The CI → Git update → CD sync loop

## Next steps

Once comfortable with this lab, you can extend it:

- Add a `staging` and `prod` Kustomize overlay
- Add Tekton Triggers for webhook-driven pipelines
- Split into app repo + config repo pattern
- Add Sealed Secrets or External Secrets for credentials
- Gate prod deploys with manual Argo CD sync or PR approvals

## License

MIT — use freely for learning and experimentation.
