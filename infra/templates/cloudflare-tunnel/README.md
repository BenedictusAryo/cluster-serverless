# Cloudflare Tunnel - GitOps Configuration

This directory contains Cloudflare Tunnel deployment templates with **two modes**:

## Mode 1: Token-Based (Default - Simpler)

**Current setup** - Good for getting started quickly.

### How it works:
- Uses `--token` flag to authenticate
- Ingress rules configured **manually** in Cloudflare dashboard
- Secret only contains `tunnel-token`

### Pros:
- ✅ Simple setup - just one token needed
- ✅ Easy to get started
- ✅ Works with any tunnel type

### Cons:
- ❌ Routes must be configured manually in dashboard
- ❌ Not fully GitOps (routes not in Git)
- ❌ Changes require dashboard access

### Setup:
```bash
# 1. Generate sealed secret
cd cluster-serverless
./scripts/generate-sealed-secret.sh

# 2. Commit and push
git add infra/templates/cloudflare-tunnel/secret.yaml
git commit -m "Add Cloudflare Tunnel secret"
git push

# 3. Configure routes in Cloudflare dashboard
# https://one.dash.cloudflare.com/ → Tunnels → Public Hostname
```

---

## Mode 2: Config-Based (Full GitOps)

**Optional upgrade** - For full infrastructure-as-code.

### How it works:
- Uses `config.yaml` from ConfigMap
- Ingress rules defined in `values.yaml` and applied via Git
- Secret contains `credentials.json` file

### Pros:
- ✅ Fully GitOps - all routes in Git
- ✅ Changes via pull requests
- ✅ Automatic route updates on sync
- ✅ Version controlled routing

### Cons:
- ❌ Requires tunnel ID and credentials.json
- ❌ More complex initial setup
- ❌ Need to manage credentials file

### Setup:

#### Step 1: Get tunnel credentials

```bash
# In Cloudflare dashboard:
# 1. Go to Zero Trust → Networks → Tunnels
# 2. Create a new tunnel or select existing
# 3. Note the Tunnel ID (from URL or overview page)
# 4. Download credentials.json:
#    - For new tunnels: shown during creation
#    - For existing: may need to regenerate
```

#### Step 2: Create sealed secret with credentials.json

```bash
# Create secret with credentials file
kubectl create secret generic cloudflare-tunnel-secret \
  --namespace=cloudflare-tunnel \
  --from-file=credentials.json=./credentials.json \
  --dry-run=client -o yaml | \
kubeseal --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  --format=yaml > /tmp/sealed-secret.yaml

# Update the secret template
cat > infra/templates/cloudflare-tunnel/secret.yaml <<EOF
# Cloudflare Tunnel Sealed Secret (Config-based mode)
# Generated on: $(date)
{{- if .Values.cloudflareTunnel.enabled }}
$(cat /tmp/sealed-secret.yaml)
{{- end }}
EOF
```

#### Step 3: Update values.yaml

```yaml
cloudflareTunnel:
  enabled: true
  useConfigFile: true  # Enable config mode
  tunnelId: "your-tunnel-id-here"  # From Cloudflare dashboard
  
  ingress:
    # These routes are now automatically applied!
    - hostname: "*.benedict-aryo.com"
      service: http://kourier-gateway.kourier-system.svc.cluster.local:80
    - hostname: argocd.benedict-aryo.com
      service: https://argocd-server.argocd.svc.cluster.local:443
      originRequest:
        noTLSVerify: true
```

#### Step 4: Deploy

```bash
git add infra/templates/cloudflare-tunnel/secret.yaml infra/values.yaml
git commit -m "Enable config-based Cloudflare Tunnel with GitOps routes"
git push
```

### Managing Routes

With config-based mode, update routes by editing `values.yaml`:

```bash
# Edit routes
vi infra/values.yaml

# Commit and push
git add infra/values.yaml
git commit -m "Add new hostname to Cloudflare Tunnel"
git push

# ArgoCD syncs automatically within 3 minutes
# Or force sync: argocd app sync cluster-serverless-infra
```

---

## Comparison

| Feature | Token-Based | Config-Based |
|---------|-------------|--------------|
| Complexity | Simple | Moderate |
| GitOps | Partial | Full |
| Route Management | Dashboard | Git |
| Secret Type | Token string | credentials.json |
| Best For | Quick start, testing | Production, teams |

---

## Troubleshooting

### Token-based mode not connecting
```bash
# Check secret
kubectl get secret cloudflare-tunnel-secret -n cloudflare-tunnel
kubectl get secret cloudflare-tunnel-secret -n cloudflare-tunnel -o jsonpath='{.data.tunnel-token}' | base64 -d

# Check pods
kubectl logs -n cloudflare-tunnel -l app.kubernetes.io/name=cloudflare-tunnel
```

### Config-based mode failing
```bash
# Verify config
kubectl get configmap cloudflare-tunnel-config -n cloudflare-tunnel -o yaml

# Check credentials
kubectl get secret cloudflare-tunnel-secret -n cloudflare-tunnel -o jsonpath='{.data.credentials\.json}' | base64 -d | jq

# Check logs
kubectl logs -n cloudflare-tunnel -l app.kubernetes.io/name=cloudflare-tunnel
```

### Routes not working
```bash
# Check tunnel status in dashboard
# https://one.dash.cloudflare.com/ → Tunnels → (your tunnel)

# Should show:
# - Status: Healthy (green)
# - Connectors: 2 active (if replicas: 2)

# Test connectivity
curl -v https://argocd.benedict-aryo.com
```

---

## Recommendation

- **Start with Token-based** - easier to set up and test
- **Upgrade to Config-based** - when you need GitOps routing or have multiple team members managing infrastructure

Both modes are production-ready and supported!
