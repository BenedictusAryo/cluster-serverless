#!/bin/bash
set -e

# Sealed Secret Generator for Cloudflare Tunnel
# This script helps create encrypted secrets for GitOps deployment

echo "🔐 Cloudflare Tunnel Sealed Secret Generator"
echo "============================================="
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

# Check if sealed-secrets controller is running
echo "🔍 Checking Sealed Secrets controller..."
if ! kubectl get deployment -n kube-system sealed-secrets-controller &>/dev/null; then
    echo "❌ Sealed Secrets controller not found in cluster"
    echo "   Install with: kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/controller.yaml"
    exit 1
fi
echo "✅ Sealed Secrets controller is running"
echo ""

# Interactive input
echo "📋 Cloudflare Tunnel Configuration"
echo "   (Get these from https://one.dash.cloudflare.com/)"
echo ""

read -p "Enter Cloudflare Tunnel Token: " TUNNEL_TOKEN
if [ -z "$TUNNEL_TOKEN" ]; then
    echo "❌ Tunnel token is required"
    exit 1
fi

read -p "Enter Cloudflare Tunnel ID (optional): " TUNNEL_ID
read -p "Enter Cloudflare Account ID (optional): " ACCOUNT_ID

# Create namespace if not exists
kubectl create namespace cloudflare-tunnel --dry-run=client -o yaml | kubectl apply -f -

# Create temporary secret
echo ""
echo "🔒 Creating sealed secret..."

TEMP_SECRET=$(mktemp)
cat > "$TEMP_SECRET" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-tunnel-secret
  namespace: cloudflare-tunnel
type: Opaque
stringData:
  tunnel-token: "${TUNNEL_TOKEN}"
EOF

# Add optional fields
if [ ! -z "$TUNNEL_ID" ]; then
    echo "  tunnel-id: \"${TUNNEL_ID}\"" >> "$TEMP_SECRET"
fi

if [ ! -z "$ACCOUNT_ID" ]; then
    echo "  account-id: \"${ACCOUNT_ID}\"" >> "$TEMP_SECRET"
fi

# Generate sealed secret
SEALED_SECRET_FILE="cloudflare-tunnel-sealed-secret.yaml"
kubeseal --format=yaml < "$TEMP_SECRET" > "$SEALED_SECRET_FILE"

# Clean up temp file
rm "$TEMP_SECRET"

echo "✅ Sealed secret generated: $SEALED_SECRET_FILE"
echo ""
echo "📝 Next Steps:"
echo "   1. Commit the sealed secret to Git:"
echo "      git add $SEALED_SECRET_FILE"
echo "      git commit -m 'Add Cloudflare Tunnel sealed secret'"
echo "      git push"
echo ""
echo "   2. Enable Cloudflare Tunnel in values.yaml:"
echo "      cloudflareTunnel:"
echo "        enabled: true"
echo ""
echo "   3. Apply the sealed secret (or let ArgoCD sync it):"
echo "      kubectl apply -f $SEALED_SECRET_FILE"
echo ""
echo "   4. Verify the secret was created:"
echo "      kubectl get secret cloudflare-tunnel-secret -n cloudflare-tunnel"
echo ""
echo "🌐 Your services will be accessible via:"
echo "   - https://*.benedict-aryo.com (Knative services)"
echo "   - https://argocd.benedict-aryo.com (ArgoCD UI)"
echo "   - https://jaeger.benedict-aryo.com (Jaeger tracing)"
echo ""
