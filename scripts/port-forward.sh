#!/usr/bin/env bash
# Port-forward helpers for the lab.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/port-forward.sh <target>

Targets:
  argocd   Argo CD UI at https://localhost:8080
  app      Polaris app at http://localhost:8888

EOF
}

target="${1:-}"
case "${target}" in
  argocd)
    echo "Argo CD UI: https://localhost:8080 (user: admin)"
    kubectl port-forward svc/argocd-server -n argocd 8080:443
    ;;
  app)
    echo "Polaris app: http://localhost:8888"
    kubectl port-forward svc/polaris-app -n polaris-dev 8888:80
    ;;
  *)
    usage
    exit 1
    ;;
esac
