#!/usr/bin/env bash
set -euo pipefail

log() { printf '\n==> %s\n' "$*"; }

log "Installing Argo CD"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

log "Waiting for Argo CD server"
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s

log "Argo CD is ready"
log "Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "(secret not ready yet)"
echo
