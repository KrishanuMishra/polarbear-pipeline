# 01 — Prerequisites

Before starting the lab, install and verify the following tools.

## Required tools

### minikube

Local Kubernetes cluster. Recommended settings are applied by the setup script.

```bash
# macOS
brew install minikube

# Verify
minikube version
```

### kubectl

Kubernetes command-line tool.

```bash
# macOS
brew install kubectl

# Verify
kubectl version --client
```

### Docker

Used to build the initial image via minikube's Docker daemon.

```bash
# macOS
brew install --cask docker

# Verify Docker is running
docker info
```

### git

```bash
git --version
```

## Recommended tools

These are not required but helpful during the lab:

| Tool | Install | Use |
|------|---------|-----|
| `kustomize` | `brew install kustomize` | Preview rendered manifests locally |
| `tkn` | `brew install tektoncd-cli` | Tekton CLI for pipeline debugging |
| `argocd` | `brew install argocd` | Argo CD CLI |

## Git remote repository

Argo CD watches a **Git remote** — it cannot use only local files on your laptop. You need one of:

- **GitHub** (recommended for this lab)
- GitLab
- Bitbucket
- A self-hosted Git server (Gitea, etc.)

### Create a GitHub repository

1. Create a new repo on GitHub (public or private)
2. Push this project to it (see [README](../README.md))
3. Set `GIT_REPO_URL` in `config/lab.env`

### GitHub personal access token (PAT)

Tekton's `update-manifests` task pushes image tag changes back to Git. For private repos (or to avoid rate limits), create a PAT:

1. GitHub → Settings → Developer settings → Personal access tokens
2. Create a token with `repo` scope
3. Add to `config/lab.env`:

```bash
export GIT_TOKEN=ghp_your_token_here
```

## System requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 2 cores | 4 cores |
| RAM | 4 GB | 6–8 GB |
| Disk | 10 GB free | 20 GB free |

The setup script starts minikube with `--cpus=4 --memory=6144`.

## Verify everything before starting

```bash
minikube version
kubectl version --client
docker info
git --version
```

## Next

→ [02-architecture.md](02-architecture.md)
