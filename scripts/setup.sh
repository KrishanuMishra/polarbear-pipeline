#!/usr/bin/env bash
# Polaris GitOps Lab — setup for KIND or minikube
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/config/lab.env"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

load_config() {
  if [[ -f "${CONFIG_FILE}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
    set +a
  fi
  CLUSTER_TYPE="${CLUSTER_TYPE:-kind}"
  KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-polaris}"
  MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
  GIT_BRANCH="${GIT_BRANCH:-main}"
  IMAGE_TAG="${IMAGE_TAG:-v0.1.0}"
}

usage() {
  cat <<'EOF'
Usage: ./scripts/setup.sh [command]

Commands:
  all               Run the full lab bootstrap (default)
  cluster           Create/prepare cluster (KIND or minikube per config/lab.env)
  kind              Create KIND cluster + local registry
  minikube          Start minikube with required addons
  tekton            Install Tekton Pipelines
  argocd            Install Argo CD
  registry          Build and push the initial app image
  tekton-resources  Apply Tekton tasks, pipeline, and RBAC
  argocd-app        Register the Argo CD Application
  verify            Print cluster and component status

Set CLUSTER_TYPE in config/lab.env:
  CLUSTER_TYPE=kind       (default)
  CLUSTER_TYPE=minikube

Before running:
  1. Copy config/lab.env.example to config/lab.env
  2. Set GIT_REPO_URL and GIT_TOKEN
  3. Push this repo to that remote

EOF
}

cmd_cluster() {
  case "${CLUSTER_TYPE}" in
    kind) "${ROOT_DIR}/scripts/setup-kind.sh" ;;
    minikube) cmd_minikube ;;
    *) die "Unknown CLUSTER_TYPE: ${CLUSTER_TYPE}. Set kind or minikube in config/lab.env" ;;
  esac
  "${ROOT_DIR}/scripts/configure-manifests.sh"
}

cmd_minikube() {
  log "Starting minikube profile: ${MINIKUBE_PROFILE}"
  minikube start -p "${MINIKUBE_PROFILE}" \
    --cpus=4 \
    --memory=6144 \
    --driver=docker

  log "Enabling addons: registry, metrics-server, ingress"
  minikube addons enable registry -p "${MINIKUBE_PROFILE}"
  minikube addons enable metrics-server -p "${MINIKUBE_PROFILE}"
  minikube addons enable ingress -p "${MINIKUBE_PROFILE}"

  log "Pointing kubectl at minikube"
  kubectl config use-context "${MINIKUBE_PROFILE}"

  log "Waiting for registry pod"
  kubectl rollout status deployment/registry -n kube-system --timeout=120s
}

cmd_tekton() {
  "${ROOT_DIR}/scripts/install-tekton.sh"
}

cmd_argocd() {
  "${ROOT_DIR}/scripts/install-argocd.sh"
}

cmd_registry() {
  "${ROOT_DIR}/scripts/build-initial-image.sh"
}

cmd_tekton_resources() {
  log "Applying Tekton namespace and RBAC"
  kubectl apply -f "${ROOT_DIR}/tekton/namespace.yaml"
  kubectl apply -f "${ROOT_DIR}/tekton/serviceaccount.yaml"

  log "Applying Tekton tasks and pipeline"
  kubectl apply -f "${ROOT_DIR}/tekton/tasks/"
  kubectl apply -f "${ROOT_DIR}/tekton/pipelines/"

  if [[ -n "${GIT_TOKEN:-}" ]]; then
    log "Creating git-credentials secret for Tekton"
    kubectl create secret generic git-credentials \
      -n polaris-pipeline \
      --from-literal=token="${GIT_TOKEN}" \
      --dry-run=client -o yaml | kubectl apply -f -
  else
    log "WARNING: GIT_TOKEN not set in config/lab.env"
    log "Tekton cannot push manifest updates. See docs/09-github-token.md"
  fi
}

cmd_argocd_app() {
  [[ -n "${GIT_REPO_URL:-}" ]] || die "Set GIT_REPO_URL in config/lab.env"

  log "Applying Argo CD Application for polaris-dev"
  sed "s|REPLACE_WITH_YOUR_GIT_URL|${GIT_REPO_URL}|g" \
    "${ROOT_DIR}/argocd/applications/polaris-dev.yaml" | kubectl apply -f -

  if [[ -n "${GIT_TOKEN:-}" ]]; then
    log "Configuring Argo CD repository credentials (private repo support)"
    kubectl -n argocd create secret generic repo-polaris \
      --from-literal=type=git \
      --from-literal=url="${GIT_REPO_URL}" \
      --from-literal=password="${GIT_TOKEN}" \
      --from-literal=username=git \
      --dry-run=client -o yaml | kubectl apply -f -
    kubectl label secret repo-polaris -n argocd \
      argocd.argoproj.io/secret-type=repository --overwrite
  fi

  log "Waiting for application sync (may take a minute)"
  kubectl -n argocd wait --for=condition=Synced application/polaris-dev --timeout=180s || true
}

cmd_verify() {
  log "Cluster type: ${CLUSTER_TYPE}"
  log "Cluster nodes"
  kubectl get nodes

  log "Tekton"
  kubectl get pods -n tekton-pipelines 2>/dev/null || echo "Tekton not installed"

  log "Argo CD"
  kubectl get pods -n argocd 2>/dev/null || echo "Argo CD not installed"

  log "Polaris app"
  kubectl get all -n polaris-dev 2>/dev/null || echo "App not deployed yet"

  log "Argo CD applications"
  kubectl get applications -n argocd 2>/dev/null || true
}

cmd_all() {
  cmd_cluster
  cmd_tekton
  cmd_argocd
  cmd_registry
  cmd_tekton_resources
  cmd_argocd_app
  cmd_verify

  cat <<EOF

================================================================================
Lab bootstrap complete! (${CLUSTER_TYPE})

Next steps:
  1. Argo CD UI:  ./scripts/port-forward.sh argocd
  2. App access:  ./scripts/port-forward.sh app
  3. Run CI:      ./scripts/run-pipeline.sh

Argo CD admin password:
  kubectl -n argocd get secret argocd-initial-admin-secret \\
    -o jsonpath='{.data.password}' | base64 -d; echo

EOF
}

main() {
  load_config
  local command="${1:-all}"

  case "${command}" in
    all) cmd_all ;;
    cluster) cmd_cluster ;;
    kind) CLUSTER_TYPE=kind; cmd_cluster ;;
    minikube) CLUSTER_TYPE=minikube; cmd_cluster ;;
    tekton) cmd_tekton ;;
    argocd) cmd_argocd ;;
    registry) cmd_registry ;;
    tekton-resources) cmd_tekton_resources ;;
    argocd-app) cmd_argocd_app ;;
    verify) cmd_verify ;;
    -h|--help|help) usage ;;
    *) die "Unknown command: ${command}. Run ./scripts/setup.sh help" ;;
  esac
}

main "$@"
