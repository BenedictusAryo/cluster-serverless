#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_APP="${SCRIPT_DIR}/root-application.yaml"
ARGO_NS="argocd"

command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required"; exit 1; }

echo "[1/3] Installing Argo CD..."
kubectl create namespace "${ARGO_NS}" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n "${ARGO_NS}" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "[2/3] Waiting for Argo CD to be ready..."
kubectl -n "${ARGO_NS}" rollout status deployment/argocd-server --timeout=180s
kubectl -n "${ARGO_NS}" rollout status deployment/argocd-application-controller --timeout=180s

echo "[3/3] Applying root Argo CD Application..."
kubectl apply -f "${ROOT_APP}"

echo "Bootstrap complete. Argo CD is now reconciling applications defined in ${ROOT_APP}."
