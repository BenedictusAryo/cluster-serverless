#!/bin/bash
set -e

# K0s Single-Node VPS Installation Script
# Controller + Worker on the same node

echo "🚀 K0s Single-Node VPS Installation"
echo "===================================="
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="${SCRIPT_DIR}/../config/k0s.yaml"

# Check prerequisites
echo "📋 Checking prerequisites..."
if ! command -v curl &> /dev/null; then
    echo "❌ curl not found, installing..."
    sudo apt-get update && sudo apt-get install -y curl
fi

# Detect IP
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "✅ Detected VPS IP: ${SERVER_IP}"
echo ""

# Download k0s
echo "📦 Downloading k0s..."
curl -sSLf https://get.k0s.sh | sudo sh
echo "✅ k0s installed"
echo ""

sudo mkdir -p /etc/k0s

INSTALL_CMD="sudo k0s install controller --enable-worker --no-taints"

# Use custom config if exists
if [ -f "${CONFIG_FILE}" ]; then
    echo "📝 Using config: ${CONFIG_FILE}"
    sudo cp "${CONFIG_FILE}" /etc/k0s/k0s.yaml

    read -p "Enter VPS public IP (default: ${SERVER_IP}): " PUBLIC_IP
    PUBLIC_IP=${PUBLIC_IP:-$SERVER_IP}

    # Add SAN if different
    if [ "${PUBLIC_IP}" != "${SERVER_IP}" ]; then
        echo "Adding ${PUBLIC_IP} to API server SANs..."
        sudo sed -i "/sans:/a\      - ${PUBLIC_IP}" /etc/k0s/k0s.yaml
    fi

    INSTALL_CMD="${INSTALL_CMD} --config /etc/k0s/k0s.yaml"
else
    PUBLIC_IP="${SERVER_IP}"
    echo "⚠️  No custom config found, using defaults"
fi

echo "✅ Installing k0s as single-node (controller + worker)..."
$INSTALL_CMD

echo ""
echo "🔄 Starting k0s..."
sudo k0s start

# Wait for API server
echo "⏳ Waiting for API server..."
retries=0
max_retries=30
until sudo k0s kubectl get nodes &>/dev/null; do
    retries=$((retries+1))
    if [ $retries -gt $max_retries ]; then
        echo "❌ Timeout waiting for API server"
        exit 1
    fi
    sleep 5
done

echo "✅ API server is ready"
echo ""

# Setup kubeconfig
echo "🔑 Setting up kubeconfig..."
mkdir -p ~/.kube
sudo k0s kubeconfig admin > ~/.kube/config
chmod 600 ~/.kube/config
echo "✅ Kubeconfig written to ~/.kube/config"
echo ""

echo "========================================"
echo "🎉 K0s Single-Node Installation Complete!"
echo "========================================"
echo ""
echo "📊 Cluster status:"
sudo k0s kubectl get nodes
echo ""
echo "🔗 API Server:"
echo "   https://${PUBLIC_IP}:6443"
echo ""
echo "🔍 Useful commands:"
echo "   kubectl get pods -A"
echo "   sudo k0s status"
echo "   sudo journalctl -u k0scontroller -f"
echo ""