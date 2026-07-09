# 09 — GitHub Personal Access Token (GIT_TOKEN)

Tekton's `update-manifests` task **pushes commits back to Git** (image tag bumps). For that it needs a GitHub token with write access to your repository.

Your repo: `https://github.com/KrishanuMishra/polarbear-pipeline`

## Create a token (fine-grained — recommended)

1. Open **GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens**
   - Direct link: https://github.com/settings/personal-access-tokens
2. Click **Generate new token**
3. Configure:
   - **Token name:** `polaris-pipeline-tekton`
   - **Expiration:** 90 days (or your preference)
   - **Repository access:** Only select repositories → choose `polarbear-pipeline`
   - **Permissions → Repository permissions:**
     - **Contents:** Read and write (required to push manifest commits)
     - **Metadata:** Read-only (auto-selected)
4. Click **Generate token**
5. Copy the token immediately — it starts with `github_pat_...`

## Create a token (classic — simpler)

1. Open https://github.com/settings/tokens
2. **Generate new token (classic)**
3. Note: `polaris-pipeline-tekton`
4. Expiration: 90 days
5. Scopes: check **`repo`** (full control of private repositories)
6. Generate and copy — starts with `ghp_...`

## Add to config/lab.env

Edit `config/lab.env`:

```bash
GIT_TOKEN=github_pat_xxxxxxxxxxxxxxxxxxxx
```

Or for classic:

```bash
GIT_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
```

No quotes needed. The file is gitignored — your token will not be committed.

## Apply the secret to the cluster

After setting `GIT_TOKEN` in `config/lab.env`:

```bash
./scripts/setup.sh tekton-resources
```

This creates the `git-credentials` secret in the `polaris-pipeline` namespace.

Verify:

```bash
kubectl get secret git-credentials -n polaris-pipeline
```

## Does Argo CD need the token?

| Component | Needs token? | Why |
|-----------|--------------|-----|
| **Tekton** | Yes (for push) | Pushes `ci: bump polaris-app to vX` commits |
| **Argo CD** | Only if repo is private | Reads manifests from Git |

### Private repository

Add the repo in Argo CD:

```bash
kubectl -n argocd create secret generic repo-polarbear \
  --from-literal=type=git \
  --from-literal=url=https://github.com/KrishanuMishra/polarbear-pipeline.git \
  --from-literal=password="${GIT_TOKEN}" \
  --from-literal=username=git \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl label secret repo-polarbear -n argocd argocd.argoproj.io/secret-type=repository --overwrite
```

### Public repository

Argo CD can read without a token. Tekton still needs `GIT_TOKEN` to push manifest updates.

## Test the token

```bash
# Load your token
source config/lab.env

# Test read access
curl -s -H "Authorization: token ${GIT_TOKEN}" \
  https://api.github.com/repos/KrishanuMishra/polarbear-pipeline | head -5

# Should return JSON with "full_name": "KrishanuMishra/polarbear-pipeline"
# A 404 means wrong repo name or no access
```

## Security tips

- Never commit `GIT_TOKEN` to Git
- Use fine-grained tokens scoped to one repo
- Rotate tokens before they expire
- Revoke unused tokens at https://github.com/settings/tokens

## Next

→ [03-kind-setup.md](03-kind-setup.md) or run `./scripts/setup.sh all`
