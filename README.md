# cluster-serverless

Serverless Application in Top of Kubernetes Cluster

A comprehensive Helm chart for deploying a complete serverless Kubernetes platform with networking, observability, and event-driven architecture components.

## Overview

This Helm chart provides a production-ready serverless platform on Kubernetes, featuring:

- **Cilium**: Advanced eBPF-based networking and security
- **Knative Serving**: Serverless workload execution and auto-scaling
- **Knative Eventing**: Event-driven architecture capabilities
- **Kourier**: Lightweight ingress controller for Knative
- **OpenTelemetry**: Comprehensive observability and metrics collection
- **Jaeger**: Distributed tracing for microservices
- **Cloudflare Tunnel**: Secure external access without exposing ports

## Prerequisites

- Kubernetes cluster (v1.25+)
- Helm 3.x installed
- kubectl configured to access your cluster

## Installation

### Quick Start

```bash
# Add the repository (if hosted)
helm repo add cluster-serverless https://benedictusaryo.github.io/cluster-serverless
helm repo update

# Install with default values
helm install my-serverless cluster-serverless/cluster-serverless
```

### Install from source

```bash
# Clone the repository
git clone https://github.com/BenedictusAryo/cluster-serverless.git
cd cluster-serverless

# Install the chart
helm install my-serverless .
```

### Custom Installation

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
