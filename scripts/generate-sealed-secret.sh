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
    echo "   Make sure you've run the k0s-cluster-bootstrap setup scripts first"
    exit 1
fi
echo "✅ Sealed Secrets controller is running"
echo ""

# Interactive input
echo "📋 Cloudflare Tunnel Configuration"
echo "   (Get your tunnel token from https://one.dash.cloudflare.com/)"
echo ""
echo "   Steps to get your tunnel token:"
echo "   1. Go to Zero Trust dashboard → Networks → Tunnels"
echo "   2. Create a new tunnel or select existing one"
echo "   3. Copy the tunnel token from the installation command"
echo ""

read -p "Enter Cloudflare Tunnel Token: " TUNNEL_TOKEN
if [ -z "$TUNNEL_TOKEN" ]; then
    echo "❌ Tunnel token is required"
    exit 1
fi

# Determine script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/../infra/templates/cloudflare-tunnel"
SECRET_FILE="${TEMPLATE_DIR}/secret.yaml"

# Create namespace if not exists (for kubeseal to work)
kubectl create namespace cloudflare-tunnel --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

# Create temporary secret
echo ""
echo "🔒 Generating sealed secret..."

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

# Generate sealed secret and update template
cat > "$SECRET_FILE" <<EOF
# Cloudflare Tunnel Sealed Secret
# Generated on: $(date)
# 
# This secret is encrypted with the cluster's Sealed Secrets public key
# and can only be decrypted by the sealed-secrets-controller in the cluster.
# 
# To regenerate: run scripts/generate-sealed-secret.sh
{{- if .Values.cloudflareTunnel.enabled }}
EOF

kubeseal --controller-name=sealed-secrets-controller \
         --controller-namespace=kube-system \
         --format=yaml < "$TEMP_SECRET" >> "$SECRET_FILE"

echo "{{- end }}" >> "$SECRET_FILE"

# Clean up temp file
rm "$TEMP_SECRET"

echo "✅ Sealed secret generated and saved to: infra/templates/cloudflare-tunnel/secret.yaml"
echo ""
echo "📝 Next Steps:"
echo ""
echo "   1. Review the generated secret:"
echo "      cat ${SECRET_FILE}"
echo ""
echo "   2. Configure Public Hostnames in Cloudflare Zero Trust dashboard:"
echo "      https://one.dash.cloudflare.com/ → Networks → Tunnels → (your tunnel)"
echo "      → Public Hostname tab → Add public hostname"
echo ""
echo "      Recommended hostnames:"
echo "      - argocd.benedict-aryo.com → argocd-server.argocd.svc.cluster.local:443"
echo "        ✓ Enable 'No TLS Verify'"
echo "      - jaeger.benedict-aryo.com → jaeger-query.observability.svc.cluster.local:16686"
echo "      - *.benedict-aryo.com → kourier-gateway.kourier-system.svc.cluster.local:80"
echo "        (For Knative Services)"
echo ""
echo "   3. Commit and push to trigger ArgoCD sync:"
echo "      git add infra/templates/cloudflare-tunnel/secret.yaml"
echo "      git commit -m 'Update Cloudflare Tunnel sealed secret'"
echo "      git push origin main"
echo ""
echo "   4. Verify deployment (after ArgoCD sync):"
echo "      kubectl get sealedsecrets -n cloudflare-tunnel"
echo "      kubectl get secret cloudflare-tunnel-secret -n cloudflare-tunnel"
echo "      kubectl get pods -n cloudflare-tunnel"
echo ""
echo "   5. Check tunnel status in Cloudflare dashboard:"
echo "      Should show as 'Healthy' with 2 connectors"
echo ""
echo "🎉 Your services will be accessible via Cloudflare Tunnel!"
echo ""
