#!/usr/bin/env bash
# Create a KIND cluster with a local container registry for the GitOps lab.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/config/lab.env"

if [[ -f "${CONFIG_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
  set +a
fi

KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-polaris}"
REGISTRY_NAME="${REGISTRY_NAME:-kind-registry}"
REGISTRY_PORT="${REGISTRY_PORT:-5000}"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

command -v kind >/dev/null || die "kind is not installed. Run: brew install kind"
command -v docker >/dev/null || die "docker is not installed"
command -v kubectl >/dev/null || die "kubectl is not installed"

# 1. Start local registry container (if not already running)
if ! docker inspect "${REGISTRY_NAME}" >/dev/null 2>&1; then
  log "Starting local registry container: ${REGISTRY_NAME}"
  docker run -d --restart=always \
    -p "127.0.0.1:${REGISTRY_PORT}:5000" \
    --name "${REGISTRY_NAME}" \
    registry:2
else
  log "Registry container ${REGISTRY_NAME} already exists"
  docker start "${REGISTRY_NAME}" 2>/dev/null || true
fi

# 2. Create KIND cluster (if not already present)
if ! kind get clusters 2>/dev/null | grep -qx "${KIND_CLUSTER_NAME}"; then
  log "Creating KIND cluster: ${KIND_CLUSTER_NAME}"
  kind create cluster --name "${KIND_CLUSTER_NAME}" --config "${ROOT_DIR}/kind/kind-config.yaml"
else
  log "KIND cluster ${KIND_CLUSTER_NAME} already exists"
fi

# 3. Connect registry to the KIND docker network
REGISTRY_NETWORK="kind"
if [ "$(docker inspect -f='{{json .State.Running}}' "${REGISTRY_NAME}")" != "true" ]; then
  die "Registry container is not running"
fi

if ! docker network inspect "${REGISTRY_NETWORK}" >/dev/null 2>&1; then
  die "Docker network '${REGISTRY_NETWORK}' not found. Is the cluster running?"
fi

if ! docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${REGISTRY_NAME}" | grep -q '"kind"'; then
  log "Connecting ${REGISTRY_NAME} to docker network: ${REGISTRY_NETWORK}"
  docker network connect "${REGISTRY_NETWORK}" "${REGISTRY_NAME}" || true
fi

# 4. Configure nodes to use the local registry (containerd certs.d)
REG_DIR="/etc/containerd/certs.d/localhost:${REGISTRY_PORT}"
log "Configuring containerd on KIND nodes for localhost:${REGISTRY_PORT}"
for node in $(kind get nodes --name "${KIND_CLUSTER_NAME}"); do
  docker exec "${node}" mkdir -p "${REG_DIR}"
  cat <<EOF | docker exec -i "${node}" cp /dev/stdin "${REG_DIR}/hosts.toml"
[host."http://${REGISTRY_NAME}:5000"]
EOF
done

# 5. Install metrics-server (useful for Argo CD / kubectl top)
log "Installing metrics-server"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml 2>/dev/null || true
kubectl patch deployment metrics-server -n kube-system --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' \
  2>/dev/null || true

log "KIND cluster ready"
log "  context:     kind-${KIND_CLUSTER_NAME}"
log "  registry:    localhost:${REGISTRY_PORT} (host push/pull)"
log "  in-cluster:  localhost:${REGISTRY_PORT}/polaris-app:tag (via mirror)"
log "  kaniko push: host.docker.internal:${REGISTRY_PORT}"

kubectl cluster-info --context "kind-${KIND_CLUSTER_NAME}"
