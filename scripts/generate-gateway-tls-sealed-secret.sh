#!/bin/bash
set -e

# Sealed Secret Generator for Gateway TLS
# This script helps create a sealed TLS secret for the Gateway

echo "🔐 Gateway TLS Sealed Secret Generator"
echo "========================================="
echo ""

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is required but not installed"
    exit 1
fi

if ! command -v kubeseal &> /dev/null; then
    echo "❌ kubeseal is required but not installed"
    echo "   Install with: https://github.com/bitnami-labs/sealed-secrets#installation"
    exit 1
fi

echo "📋 TLS Certificate for Gateway"
echo "   You need a PEM-encoded certificate and key."
echo "   (You can use a real cert or generate a self-signed one with openssl)"
echo ""
echo "How do you want to provide the TLS certificate and key?"
echo "  1) Generate new self-signed certificate (default)"
echo "  2) Use existing certificate and key files"
read -p "Select option [1/2]: " CERT_OPTION
CERT_OPTION=${CERT_OPTION:-1}

if [ "$CERT_OPTION" = "2" ]; then
    read -p "Enter path to TLS certificate (tls.crt): " TLS_CRT
    if [ ! -f "$TLS_CRT" ]; then
        echo "❌ Certificate file not found: $TLS_CRT"
        exit 1
    fi
    read -p "Enter path to TLS private key (tls.key): " TLS_KEY
    if [ ! -f "$TLS_KEY" ]; then
        echo "❌ Key file not found: $TLS_KEY"
        exit 1
    fi
else
    if ! command -v openssl &> /dev/null; then
        echo "❌ openssl is required to generate a self-signed certificate but is not installed."
        exit 1
    fi
    echo "Generating new self-signed certificate using openssl..."
    TLS_CRT="$(mktemp)"
    TLS_KEY="$(mktemp)"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -subj "/CN=*.benedict-aryo.com" \
        -keyout "$TLS_KEY" -out "$TLS_CRT"
    echo "  Self-signed certificate generated for CN=*.benedict-aryo.com (valid 1 year)"
fi

# Set output location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/../infra/templates/gateway"
SECRET_FILE="${TEMPLATE_DIR}/tls-secret.yaml"

# Create namespace if not exists
kubectl create namespace gateway-system --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

# Create temporary secret
TEMP_SECRET=$(mktemp)
kubectl create secret tls wildcard-tls-cert \
  --cert="$TLS_CRT" \
  --key="$TLS_KEY" \
  -n gateway-system --dry-run=client -o yaml > "$TEMP_SECRET"

echo ""
echo "🔒 Generating sealed secret..."

cat > "$SECRET_FILE" <<EOF
# Gateway TLS Sealed Secret
# Generated on: $(date)
#
# This secret is encrypted with the cluster's Sealed Secrets public key
# and can only be decrypted by the sealed-secrets-controller in the cluster.
#
# To regenerate: run scripts/generate-gateway-tls-sealed-secret.sh
{{- if .Values.gateway.tls.enabled }}
EOF

kubeseal --controller-name=sealed-secrets-controller \
         --controller-namespace=kube-system \
         --format=yaml < "$TEMP_SECRET" >> "$SECRET_FILE"

echo "{{- end }}" >> "$SECRET_FILE"

rm "$TEMP_SECRET"

echo "✅ Sealed secret generated and saved to: infra/templates/gateway/tls-secret.yaml"
echo ""
echo "📝 Next Steps:"
echo ""
echo "   1. Review the generated secret:"
echo "      cat ${SECRET_FILE}"
echo ""
echo "   2. Commit and push to trigger ArgoCD sync:"
echo "      git add infra/templates/gateway/tls-secret.yaml"
echo "      git commit -m 'Update Gateway TLS sealed secret'"
echo "      git push origin main"
echo ""
echo "   3. Verify deployment (after ArgoCD sync):"
echo "      kubectl get sealedsecrets -n gateway-system"
echo "      kubectl get secret wildcard-tls-cert -n gateway-system"
echo ""
echo "🎉 Your Gateway will have a permanent, GitOps-managed TLS Secret!"
echo ""