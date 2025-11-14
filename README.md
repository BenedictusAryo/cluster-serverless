# cluster-serverless

**GitOps-Powered Serverless Platform for VPS/Homelab** 🚀

A production-ready, Helm-based serverless Kubernetes platform optimized for:
- 🏠 **Homelab deployments** (works behind CGNAT!)
- ☁️ **VPS hosting** (single or multi-node)
- 🔀 **Hybrid setups** (VPS controller + homelab workers)
- 💰 **Cost-effective** serverless at 70-90% savings vs managed platforms

## 🎯 What This Provides

A complete serverless stack deployed via GitOps (ArgoCD) including:

- **🕸️ Cilium** - eBPF-based networking (50-70% lighter than Istio)
- **🔄 Knative Serving** - Auto-scaling HTTP services (scale-to-zero)
- **⚡ Knative Eventing** - Event-driven architecture
- **🚪 Kourier** - Lightweight ingress (production-ready alternative to Istio)
- **📊 OpenTelemetry** - Distributed tracing and metrics
- **🔍 Jaeger** - Tracing UI and analysis
- **🔒 Cloudflare Tunnel** - Secure external access (no exposed ports!)

## 🌟 Why This Stack?

### Traditional Serverless Challenges
- ❌ Expensive ($200-400/month for managed K8s)
- ❌ Vendor lock-in (AWS Lambda, Cloud Run, etc.)
- ❌ Heavy resource requirements (Istio service mesh)
- ❌ Can't run on homelab behind CGNAT
- ❌ Complex networking and SSL setup

### Our Solution
- ✅ **$15-120/month** (70-90% cost savings)
- ✅ **Portable** (runs anywhere Kubernetes runs)
- ✅ **Lightweight** (Kourier + Cilium vs Istio)
- ✅ **Works behind CGNAT** (Cloudflare Tunnel)
- ✅ **Automatic SSL/TLS** (via Cloudflare)
- ✅ **GitOps-managed** (declarative, version-controlled)

## 📚 Prerequisites

### Kubernetes Cluster
Deployed via [k0s-cluster-bootstrap](https://github.com/BenedictusAryo/k0s-cluster-bootstrap):
- **Kubernetes**: 1.28+ (via k0s)
- **Nodes**: 1-10 (VPS/homelab mix supported)
- **Resources**: 8GB RAM, 4 vCPU minimum per node

### External Requirements
- **Domain**: Managed in Cloudflare DNS (e.g., `benedict-aryo.com`)
- **ArgoCD**: Installed and configured
- **Sealed Secrets**: For secure secret management

## 🚀 Installation

### Automated Deployment (Recommended)

This chart is automatically deployed via ArgoCD when you run the [k0s-cluster-bootstrap](https://github.com/BenedictusAryo/k0s-cluster-bootstrap) setup:

```bash
# From k0s-cluster-bootstrap repository
./scripts/setup-argocd.sh
```

ArgoCD will:
1. Deploy this Helm chart
2. Install all components (Cilium, Knative, Kourier, etc.)
3. Configure networking and observability
4. Set up automatic sync and self-healing

### Manual Deployment (Development)

For testing or development:

```bash
# Clone the repository
git clone https://github.com/BenedictusAryo/cluster-serverless.git
cd cluster-serverless

# Install with Helm
helm install cluster-serverless . \
  --create-namespace \
  --namespace serverless-system \
  --set global.domain=benedict-aryo.com
```

Create a custom `values.yaml` file:

```yaml
# custom-values.yaml
cilium:
  enabled: true
  hubble:
    enabled: true

knativeServing:
  enabled: true
  autoscaling:
    minScale: 0
    maxScale: 20

jaeger:
  enabled: true
  storage:
    type: memory

cloudflareTunnel:
  enabled: true
  tunnelToken: "your-tunnel-token-here"
```

Install with custom values:

```bash
helm install my-serverless . -f custom-values.yaml
```

## Configuration

### Global Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.clusterName` | Name of the cluster | `cluster-serverless` |
| `global.namespace` | Default namespace | `serverless-system` |

### Cilium Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cilium.enabled` | Enable Cilium CNI | `true` |
| `cilium.version` | Cilium version | `1.14.5` |
| `cilium.hubble.enabled` | Enable Hubble observability | `true` |
| `cilium.kubeProxyReplacement` | kube-proxy replacement mode | `strict` |

### Knative Serving Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `knativeServing.enabled` | Enable Knative Serving | `true` |
| `knativeServing.version` | Knative Serving version | `1.11.0` |
| `knativeServing.autoscaling.minScale` | Minimum replicas | `0` |
| `knativeServing.autoscaling.maxScale` | Maximum replicas | `10` |

### Knative Eventing Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `knativeEventing.enabled` | Enable Knative Eventing | `true` |
| `knativeEventing.version` | Knative Eventing version | `1.11.0` |
| `knativeEventing.broker.type` | Broker type | `MTChannelBasedBroker` |

### Kourier Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `kourier.enabled` | Enable Kourier ingress | `true` |
| `kourier.service.type` | Service type | `LoadBalancer` |

### OpenTelemetry Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `opentelemetry.enabled` | Enable OpenTelemetry | `true` |
| `opentelemetry.collector.replicas` | Number of collector replicas | `1` |
| `opentelemetry.exporters.jaeger.enabled` | Export to Jaeger | `true` |

### Jaeger Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `jaeger.enabled` | Enable Jaeger | `true` |
| `jaeger.strategy` | Deployment strategy | `allInOne` |
| `jaeger.storage.type` | Storage type | `memory` |

### Cloudflare Tunnel Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cloudflareTunnel.enabled` | Enable Cloudflare Tunnel | `false` |
| `cloudflareTunnel.tunnelToken` | Tunnel token | `""` |
| `cloudflareTunnel.replicas` | Number of replicas | `2` |

## Usage

### Deploy a Serverless Application

Once the chart is installed, you can deploy serverless applications using Knative:

```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: hello-world
spec:
  template:
    spec:
      containers:
        - image: gcr.io/knative-samples/helloworld-go
          env:
            - name: TARGET
              value: "World"
```

### Access Jaeger UI

```bash
kubectl port-forward -n observability svc/jaeger-query 16686:16686
# Access at http://localhost:16686
```

### View Hubble Network Flow

```bash
kubectl port-forward -n kube-system svc/hubble-ui 12000:80
# Access at http://localhost:12000
```

## Upgrading

```bash
helm upgrade my-serverless . -f custom-values.yaml
```

## Uninstalling

```bash
helm uninstall my-serverless
```

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    External Traffic                      │
└───────────────────┬─────────────────────────────────────┘
                    │
         ┌──────────▼──────────┐
         │ Cloudflare Tunnel   │ (Optional)
         │  (Secure Access)    │
         └──────────┬──────────┘
                    │
         ┌──────────▼──────────┐
         │      Kourier        │
         │   (Ingress/LB)      │
         └──────────┬──────────┘
                    │
         ┌──────────▼──────────┐
         │  Knative Serving    │
         │  (Serverless Apps)  │
         └──────────┬──────────┘
                    │
    ┌───────────────┴───────────────┐
    │                               │
┌───▼────┐                   ┌──────▼──────┐
│ Cilium │                   │  Knative    │
│  (CNI) │                   │  Eventing   │
└────────┘                   └──────┬──────┘
                                    │
                        ┌───────────┴───────────┐
                        │                       │
                 ┌──────▼────────┐      ┌──────▼─────┐
                 │ OpenTelemetry │      │   Jaeger   │
                 │  (Collector)  │      │ (Tracing)  │
                 └───────────────┘      └────────────┘
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n knative-serving
kubectl get pods -n knative-eventing
kubectl get pods -n observability
```

### View Logs

```bash
kubectl logs -n knative-serving -l app=controller
kubectl logs -n observability -l app.kubernetes.io/name=jaeger
```

### Common Issues

1. **Pods not starting**: Check resource availability and node capacity
2. **Services not accessible**: Verify Kourier service type and external IP
3. **Tracing not working**: Ensure OpenTelemetry is configured to export to Jaeger

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

See [LICENSE](LICENSE) file for details.

## Support

For issues and questions:
- GitHub Issues: https://github.com/BenedictusAryo/cluster-serverless/issues
- Documentation: https://github.com/BenedictusAryo/cluster-serverless
