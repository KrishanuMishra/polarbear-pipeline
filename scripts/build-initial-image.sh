#!/usr/bin/env bash
# Build the initial Polaris image and push it to the minikube registry.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/config/lab.env"

if [[ -f "${CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
fi

IMAGE_TAG="${IMAGE_TAG:-v0.1.0}"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
REGISTRY="localhost:5000"
IMAGE="${REGISTRY}/polaris-app:${IMAGE_TAG}"

log() { printf '\n==> %s\n' "$*"; }

log "Using minikube Docker daemon for profile: ${MINIKUBE_PROFILE}"
eval "$(minikube -p "${MINIKUBE_PROFILE}" docker-env)"

log "Building image: ${IMAGE}"
docker build -t "${IMAGE}" "${ROOT_DIR}/app"

log "Pushing to minikube registry"
docker push "${IMAGE}"

log "Initial image pushed: ${IMAGE}"
log "ArgoCD will pull it as: registry.kube-system.svc.cluster.local:80/polaris-app:${IMAGE_TAG}"
