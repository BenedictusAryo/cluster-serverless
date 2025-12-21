#!/usr/bin/env bash
set -euo pipefail

ARGO_NS="argocd"
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required"; exit 1; }

echo "Creating namespace ${ARGO_NS} if needed..."
kubectl create namespace "${ARGO_NS}" --dry-run=client -o yaml | kubectl apply -f -

echo "Installing Argo CD manifests..."
kubectl apply -n "${ARGO_NS}" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD deployments to be ready..."
kubectl -n "${ARGO_NS}" rollout status deployment/argocd-server --timeout=180s
kubectl -n "${ARGO_NS}" rollout status deployment/argocd-application-controller --timeout=180s

kubectl -n "${ARGO_NS}" get pods
