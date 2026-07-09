#!/usr/bin/env bash
# Polaris GitOps Lab — main setup script for minikube
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
  MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
  GIT_BRANCH="${GIT_BRANCH:-main}"
  IMAGE_TAG="${IMAGE_TAG:-v0.1.0}"
}

usage() {
  cat <<'EOF'
Usage: ./scripts/setup.sh [command]

Commands:
  all           Run the full lab bootstrap (default)
  minikube      Start minikube with required addons
  tekton        Install Tekton Pipelines
  argocd        Install Argo CD
  registry      Build and push the initial app image
  tekton-resources  Apply Tekton tasks, pipeline, and RBAC
  argocd-app    Register the Argo CD Application
  verify        Print cluster and component status

Before running:
  1. Copy config/lab.env.example to config/lab.env
  2. Set GIT_REPO_URL to your remote repository
  3. Push this repo to that remote (git init, add, commit, push)

EOF
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
    log "No GIT_TOKEN in config/lab.env — Tekton git push will only work for public repos"
    log "For private repos, add: export GIT_TOKEN=ghp_... to config/lab.env"
  fi
}

cmd_argocd_app() {
  [[ -n "${GIT_REPO_URL:-}" ]] || die "Set GIT_REPO_URL in config/lab.env"

  log "Applying Argo CD Application for polaris-dev"
  sed "s|REPLACE_WITH_YOUR_GIT_URL|${GIT_REPO_URL}|g" \
    "${ROOT_DIR}/argocd/applications/polaris-dev.yaml" | kubectl apply -f -

  log "Syncing application (may take a minute)"
  kubectl -n argocd wait --for=condition=Synced application/polaris-dev --timeout=180s || true
}

cmd_verify() {
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
  cmd_minikube
  cmd_tekton
  cmd_argocd
  cmd_registry
  cmd_tekton_resources
  cmd_argocd_app
  cmd_verify

  cat <<EOF

================================================================================
Lab bootstrap complete!

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
    minikube) cmd_minikube ;;
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
