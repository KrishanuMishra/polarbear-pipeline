#!/usr/bin/env bash
# Build the initial Polaris image and push it to the local registry.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/config/lab.env"

if [[ -f "${CONFIG_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
  set +a
fi

CLUSTER_TYPE="${CLUSTER_TYPE:-kind}"
IMAGE_TAG="${IMAGE_TAG:-v0.1.0}"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
REGISTRY_PORT="${REGISTRY_PORT:-5000}"

case "${CLUSTER_TYPE}" in
  kind)
    REGISTRY_HOST="localhost:${REGISTRY_PORT}"
    ;;
  minikube)
    REGISTRY_HOST="localhost:5000"
    ;;
  *)
    REGISTRY_HOST="localhost:5000"
    ;;
esac

IMAGE="${REGISTRY_HOST}/polaris-app:${IMAGE_TAG}"

log() { printf '\n==> %s\n' "$*"; }

if [[ "${CLUSTER_TYPE}" == "minikube" ]]; then
  log "Using minikube Docker daemon for profile: ${MINIKUBE_PROFILE}"
  eval "$(minikube -p "${MINIKUBE_PROFILE}" docker-env)"
else
  log "Building on host Docker and pushing to KIND local registry"
fi

log "Building image: ${IMAGE}"
docker build -t "${IMAGE}" "${ROOT_DIR}/app"

log "Pushing to registry"
docker push "${IMAGE}"

case "${CLUSTER_TYPE}" in
  kind)
    log "Image available in cluster as: localhost:${REGISTRY_PORT}/polaris-app:${IMAGE_TAG}"
    ;;
  minikube)
    log "Image available in cluster as: registry.kube-system.svc.cluster.local:80/polaris-app:${IMAGE_TAG}"
    ;;
esac
