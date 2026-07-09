#!/usr/bin/env bash
# Apply registry URLs from config/lab.env into manifests.
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
REGISTRY_PULL="${REGISTRY_PULL:-}"
REGISTRY_PUSH="${REGISTRY_PUSH:-}"

if [[ -z "${REGISTRY_PULL}" || -z "${REGISTRY_PUSH}" ]]; then
  case "${CLUSTER_TYPE}" in
    kind)
      REGISTRY_PULL="${REGISTRY_PULL:-localhost:5000}"
      REGISTRY_PUSH="${REGISTRY_PUSH:-host.docker.internal:5000}"
      ;;
    minikube)
      REGISTRY_PULL="${REGISTRY_PULL:-registry.kube-system.svc.cluster.local:80}"
      REGISTRY_PUSH="${REGISTRY_PUSH:-registry.kube-system.svc.cluster.local:80}"
      ;;
    *)
      die "Unknown CLUSTER_TYPE: ${CLUSTER_TYPE}. Use 'kind' or 'minikube'."
      ;;
  esac
fi

log() { printf '==> %s\n' "$*"; }

KUSTOMIZATION="${ROOT_DIR}/deploy/overlays/dev/kustomization.yaml"

log "Configuring manifests for ${CLUSTER_TYPE}"
log "  REGISTRY_PULL=${REGISTRY_PULL}"
log "  REGISTRY_PUSH=${REGISTRY_PUSH}"

# Update Kustomize image registry (what Argo CD deploys)
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s|newName: .*|newName: ${REGISTRY_PULL}/polaris-app|" "${KUSTOMIZATION}"
else
  sed -i "s|newName: .*|newName: ${REGISTRY_PULL}/polaris-app|" "${KUSTOMIZATION}"
fi

# Update Tekton pipeline build destination (Kaniko push target)
PIPELINE="${ROOT_DIR}/tekton/pipelines/polaris-pipeline.yaml"
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s|value: .*/\$(params.image-name):\$(params.image-tag)|value: ${REGISTRY_PUSH}/\$(params.image-name):\$(params.image-tag)|" "${PIPELINE}"
else
  sed -i "s|value: .*/\$(params.image-name):\$(params.image-tag)|value: ${REGISTRY_PUSH}/\$(params.image-name):\$(params.image-tag)|" "${PIPELINE}"
fi

# Update build-push insecure registry default
BUILD_PUSH="${ROOT_DIR}/tekton/tasks/build-push.yaml"
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s|default: registry\\..*|default: ${REGISTRY_PUSH}|" "${BUILD_PUSH}"
  sed -i '' "s|default: host\\.docker\\..*|default: ${REGISTRY_PUSH}|" "${BUILD_PUSH}"
  sed -i '' "s|default: localhost:.*|default: ${REGISTRY_PUSH}|" "${BUILD_PUSH}"
else
  sed -i "s|default: registry\\..*|default: ${REGISTRY_PUSH}|" "${BUILD_PUSH}"
  sed -i "s|default: host\\.docker\\..*|default: ${REGISTRY_PUSH}|" "${BUILD_PUSH}"
  sed -i "s|default: localhost:.*|default: ${REGISTRY_PUSH}|" "${BUILD_PUSH}"
fi

# Update update-manifests kustomize edit line (Git should store PULL URL)
UPDATE_MANIFESTS="${ROOT_DIR}/tekton/tasks/update-manifests.yaml"
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s|kustomize edit set image.*|kustomize edit set image \"\$(params.image-name)=${REGISTRY_PULL}/\$(params.image-name):\$(params.image-tag)\"|" "${UPDATE_MANIFESTS}"
else
  sed -i "s|kustomize edit set image.*|kustomize edit set image \"\$(params.image-name)=${REGISTRY_PULL}/\$(params.image-name):\$(params.image-tag)\"|" "${UPDATE_MANIFESTS}"
fi

log "Manifests updated"
