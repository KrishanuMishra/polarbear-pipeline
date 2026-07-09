#!/usr/bin/env bash
# Run the Polaris Tekton pipeline with values from config/lab.env
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/config/lab.env"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

if [[ -f "${CONFIG_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
  set +a
fi

[[ -n "${GIT_REPO_URL:-}" ]] || die "Set GIT_REPO_URL in config/lab.env"
IMAGE_TAG="${1:-${IMAGE_TAG:-}}"
[[ -n "${IMAGE_TAG}" ]] || die "Provide an image tag argument or set IMAGE_TAG in config/lab.env"

GIT_BRANCH="${GIT_BRANCH:-main}"
RUN_NAME="polaris-run-$(date +%s)"

log() { printf '\n==> %s\n' "$*"; }

log "Creating PipelineRun: ${RUN_NAME}"
log "  git-url:    ${GIT_REPO_URL}"
log "  revision:   ${GIT_BRANCH}"
log "  image-tag:  ${IMAGE_TAG}"

sed \
  -e "s|name: polaris-pipeline-run|name: ${RUN_NAME}|" \
  -e "s|REPLACE_WITH_YOUR_GIT_URL|${GIT_REPO_URL}|g" \
  -e "s|value: v0.1.1|value: ${IMAGE_TAG}|g" \
  -e "s|value: main|value: ${GIT_BRANCH}|g" \
  "${ROOT_DIR}/tekton/pipelineruns/polaris-pipeline-run.yaml" | kubectl apply -f -

log "Watching pipeline (Ctrl+C to stop watching — the run continues)"
kubectl -n polaris-pipeline wait --for=condition=Succeeded "pipelinerun/${RUN_NAME}" --timeout=900s

log "PipelineRun succeeded. Argo CD should sync the new image tag shortly."
kubectl -n argocd get application polaris-dev -o wide 2>/dev/null || true
