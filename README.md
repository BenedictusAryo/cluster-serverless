# Knative GitOps Helm Monorepo

## Overview

This repository is a **GitOps‑oriented Helm monorepo** designed to run on a **single‑node Kubernetes cluster (k0s)** hosted on a VPS. It focuses on **serverless application deployment using Knative**, **declarative infrastructure management**, and a **clean App‑of‑Apps pattern with Argo CD**.

The repository intentionally separates **application concerns** from **platform/infrastructure concerns**, while still allowing everything to be bootstrapped from a single entry point.

This repo is meant to be:

* A **learning platform** for Kubernetes, Knative, and GitOps
* A **personal platform** for blogs, utilities, and experiments
* A **production‑like but lightweight** setup suitable for 1 VPS

---

## Goals

The primary goals of this repository are:

1. **Serverless-first deployment**

   * Applications are deployed as Knative Services
   * Scale to zero when idle
   * Simple HTTP-based workloads (blog, utilities, tools)

2. **GitOps as the source of truth**

   * Git is the single source of truth
   * All changes are declarative
   * Argo CD continuously reconciles desired state

3. **Clear separation of concerns**

   * `apps` for user workloads (Knative services)
   * `infra-apps` for platform components (Argo CD, Prometheus, etc.)

4. **Minimal but realistic platform stack**

   * k0s for Kubernetes (lightweight)
   * Traefik for edge ingress & TLS
   * Knative for serverless workloads
   * Argo CD for GitOps

5. **Bootstrap once, GitOps forever**

   * Initial cluster bootstrapping via scripts
   * After bootstrap, Argo CD manages itself and everything else

---

## High-Level Architecture

```
Internet
   |
   |  HTTPS (Let's Encrypt for benedict-aryo.com)
   v
Traefik (Edge Ingress, TLS)
   |
   v
Knative Networking (Kourier)
   |
   v
Knative Services (Apps)
```

GitOps control flow:

```
Git Repository
   |
   v
Argo CD
   |
   v
Helm (App-of-Apps)
   |
   +--> infra-apps (platform components)
   |
   +--> apps (Knative services)
```

---

## Route Management

All inbound traffic is handled by **Traefik**, the edge ingress controller. Traefik routes requests to the appropriate backend service based on the hostname. Routing is configured declaratively using Kubernetes `Ingress` resources.

There are two main categories of routes:

1.  **Infrastructure Routes**: These point to internal platform services, such as the Argo CD dashboard. These are typically configured in the `infra-apps` chart.
2.  **Application Routes**: These point to user-facing Knative services. These are configured within each application's `values.yaml` in the `/apps` directory.

### Example Routes

*   `https://benedict-aryo.com` -> Knative blog application (primary app)
*   `https://argocd.benedict-aryo.com` -> Argo CD server dashboard
*   `https://pdf.benedict-aryo.com` -> Knative PDF utility application

All routes are automatically secured with TLS certificates from Let's Encrypt.

---

## Technology Stack

### Core Platform

* **Kubernetes**: k0s (single-node, lightweight)
* **Container Runtime**: containerd (default in k0s)

### Networking

* **Edge Ingress**: Traefik
* **Knative Networking Layer**: Kourier
* **TLS**: Let's Encrypt via Traefik ACME

### Serverless

* **Knative Serving**

  * Scale-to-zero
  * Revision-based deployments
  * HTTP routing

### GitOps

* **Argo CD**

  * App-of-Apps pattern
  * Self-managed (Argo CD manages Argo CD)

* **Sealed Secrets**

  * Encrypts Kubernetes Secrets for safe storage in Git

### Observability (Infra Apps)

* Prometheus
* (Optional) Grafana

---

## Repository Structure

```
.
├── apps/
│   ├── blog/
│   │   ├── values.yaml
│   │   └── secret.yaml
│   └── pdf-utils/
│       ├── values.yaml
│       └── secret.yaml
│
├── charts/
│   └── primary-chart/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── argocd-apps.yaml
│           └── namespaces.yaml
│
├── cluster-init/
│   ├── bootstrap.sh
│   ├── install-argocd.sh
│   ├── install-k0s-single-node.sh
│   └── root-application.yaml
│
├── config/
│   └── k0s.yaml
│
└── README.md
```

## PostgreSQL

* `infra-apps/postgres.yaml` deploys PostgreSQL 17 via the Bitnami Helm chart. The chart values manage the Postgres service port and point to a SealedSecret (`postgres-admin`) for the superuser credentials.
* Each app can ship a `postgres-values.yaml` (see `apps/blog/postgres-values.yaml`) that provisions its own database, username, and password through a SealedSecret-backed job.

---

## Helm Chart Design

### Primary Helm Chart (Root Chart)

The **primary chart** is responsible for:

* Creating namespaces
* Defining Argo CD Applications
* Acting as the *App-of-Apps* root

This chart **does not deploy workloads directly**.
Instead, it tells Argo CD *what other directories to sync* (`apps/` and `infra-apps/`).

---

### Argo CD Application: `infra-apps/`

Purpose:

* Manage **platform and infrastructure components** that live under `/infra-apps`
* Provide Argo CD Projects for separation of concerns

Characteristics:

* Plain Kubernetes manifests inside the `infra-apps/` directory
* Synced by the root Argo CD Application defined in the primary chart

---

### Argo CD Application: `apps/`

Purpose:

* Deploy **user-facing applications** as Knative Services from definitions in the `/apps` directory.

Characteristics:

* **Directory-based Apps**: Each subdirectory in `/apps` represents a deployable application.
* **Knative-native**: Each application is deployed as a Knative Service.
* **Per-App Configuration**: Each app has its own `values.yaml` for configuration and an optional, encrypted `secret.yaml` for secrets. The `values.yaml` is a Knative service definition, similar to a Google Cloud Run YAML, and it includes the `Ingress` definition for routing.
* **Source-to-Image (Optional)**: Can build and deploy from a Git repository using Knative Build.

Example `apps/blog/values.yaml` (for the primary domain):

```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: blog
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/target: "10"
    spec:
      containers:
        - image: ghcr.io/benedictusaryo/personal-web-blog:latest
          ports:
            - containerPort: 8080
          env:
            - name: ENV
              value: production
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: blog-ingress
  annotations:
    kubernetes.io/ingress.class: "traefik"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  rules:
  - host: "benedict-aryo.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: blog
            port:
              number: 80
  tls:
  - hosts:
    - "benedict-aryo.com"
    secretName: blog-tls
```

Example `apps/pdf-utils/values.yaml`:

```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: pdf-utils
spec:
  template:
    spec:
      containers:
        - image: ghcr.io/benedict-aryo/pdf-utils:latest
          ports:
            - containerPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: pdf-utils-ingress
  annotations:
    kubernetes.io/ingress.class: "traefik"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  rules:
  - host: "pdf.benedict-aryo.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: pdf-utils
            port:
              number: 80
  tls:
  - hosts:
    - "pdf.benedict-aryo.com"
    secretName: pdf-utils-tls
```

Example `apps/blog/secret.yaml` (encrypted with Sealed Secrets):

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: blog-secrets
  namespace: apps
spec:
  encryptedData:
    DATABASE_URL: Ag...
```

The `apps` Helm chart will iterate through the directories in `/apps` and apply the `values.yaml` and `secret.yaml` for each one. For source-to-image builds, the `image` field in `values.yaml` would be replaced by a build step that uses the source from a Git repository, for example:

```yaml
# In a conceptual values.yaml for a source-to-image build
# This is not a direct field in the Knative Service spec,
# but would be used by the Helm chart logic to create a Knative Build resource.
source:
  git:
    url: https://github.com/BenedictusAryo/personal-web-blog.git
    revision: main
```

---

## App-of-Apps Pattern

Argo CD is configured so that:

* One **root application** points to this Git repository (`https://github.com/BenedictusAryo/cluster-serverless.git`)
* That root application installs the **primary Helm chart**
* The primary Helm chart defines **child Argo CD applications**
* Each child application points to:

  * `apps`
  * `infra-apps`

This provides:

* Clear dependency ordering
* Independent sync
* Easy scaling of apps and infra

---

## Cluster Bootstrap (`cluster-init`)

The `cluster-init` directory exists **only for first-time setup**.

### Responsibilities

* Install Argo CD into the cluster
* Apply required CRDs
* Create the root Argo CD Application

After this step:

> **All further changes are done via Git only.**

### Typical Flow

1. Create k0s cluster
2. Configure kubectl access
3. Run:

   ```bash
   cd cluster-init
   ./bootstrap.sh
   ```

What this script does:

* Installs Argo CD manifests
* Waits for Argo CD to be ready
* Applies `root-application.yaml`

---

## GitOps Workflow

1. Developer pushes change to GitHub
2. Argo CD detects drift
3. Helm templates are rendered
4. Kubernetes reconciles state

No manual `kubectl apply` is required after bootstrap.

---

## Security Considerations

* Only Traefik exposes ports 80/443
* All apps are `ClusterIP`
* HTTPS enforced everywhere
* **Secrets are encrypted** in Git using Sealed Secrets
* Admin UIs are not publicly exposed
* Git is the only control plane

---

## Who Is This For?

This repository is ideal for:

* Platform engineers
* Kubernetes learners
* Homelab enthusiasts
* Developers wanting production-like GitOps flows

---

## Future Improvements

* Gateway API migration
* External Secrets integration
* OIDC authentication for Argo CD
* Multi-cluster support
* Progressive delivery (canary/blue-green)

---

## License

MIT
