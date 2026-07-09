#!/usr/bin/env bash
set -euo pipefail

log() { printf '\n==> %s\n' "$*"; }

log "Installing Tekton Pipelines"
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

log "Waiting for Tekton controllers"
kubectl -n tekton-pipelines rollout status deployment/tekton-pipelines-controller --timeout=180s
kubectl -n tekton-pipelines rollout status deployment/tekton-pipelines-webhook --timeout=180s

log "Tekton Pipelines is ready"
