# WA-Notif (WhatsApp Notification Service)

This application deploys [go-whatsapp-web-multidevice](https://github.com/aldinokemal/go-whatsapp-web-multidevice) - a Go-based WhatsApp Web API with multi-device support.

## Overview

WA-Notif provides a REST API for sending WhatsApp messages, managing contacts, and handling WhatsApp notifications. It's deployed as a Knative service with persistent storage and PostgreSQL database support.

**Domain:** `wa-notif.benedict-aryo.com`

## Architecture

- **Knative Service**: Runs as a serverless container with `min-scale: 1` (always running)
- **Database**: PostgreSQL (shared instance in `infra` namespace)
- **Storage**: Persistent volume for WhatsApp session data
- **Secrets**: Managed via Bitnami SealedSecrets

## Files

| File | Description |
|------|-------------|
| `values.yaml` | Knative Service definition |
| `domainmapping.yaml` | Domain mapping for external access |
| `persistence.yaml` | PersistentVolume and PersistentVolumeClaim for session storage |
| `postgres-values.yaml` | Database provisioning job and credentials |
| `secret.yaml` | Application secrets (basic auth, webhooks) |

## Prerequisites

1. **Sealed Secrets Controller** - Must be installed in the cluster
2. **PostgreSQL** - Running in the `infra` namespace (provided by the cluster)
3. **kubeseal** - CLI tool for creating SealedSecrets

## Database Setup

### Step 1: Create the raw Kubernetes secret

Create a temporary file `wa-notif-db-secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: wa-notif-postgres-credentials
  namespace: apps
type: Opaque
stringData:
  database: wanotif
  username: wanotif
  password: "<your-secure-password>"
  database-uri: "postgres://wanotif:<your-secure-password>@postgres.infra.svc.cluster.local:5432/wanotif?sslmode=disable"
```

### Step 2: Create postgres-admin secret (if not exists in apps namespace)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-admin
  namespace: apps
type: Opaque
stringData:
  postgres-password: "<postgres-admin-password>"
```

### Step 3: Seal the secrets

```bash
# Seal the database credentials
kubeseal --controller-namespace kube-system \
         --controller-name sealed-secrets-controller \
         --format yaml < wa-notif-db-secret.yaml > wa-notif-db-sealed.yaml

# Seal the postgres-admin secret
kubeseal --controller-namespace kube-system \
         --controller-name sealed-secrets-controller \
         --format yaml < postgres-admin-secret.yaml > postgres-admin-sealed.yaml
```

### Step 4: Update postgres-values.yaml

Replace the placeholder values in `postgres-values.yaml` with the encrypted values from the sealed secrets.

### Step 5: Database Provisioning

The database and user will be automatically created by the `wa-notif-db-provision` Job when the application is deployed. The job:

1. Waits for PostgreSQL to be ready
2. Creates the `wanotif` database if it doesn't exist
3. Creates the `wanotif` user if it doesn't exist
4. Grants ownership of the database to the user

**Note:** The go-whatsapp-web-multidevice application will automatically create the required tables on first startup.

## Application Secrets Setup

### Step 1: Create the raw secret

Create a temporary file `wa-notif-app-secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: wa-notif-secrets
  namespace: apps
type: Opaque
stringData:
  # Format: "username:password" - multiple credentials separated by comma
  basic-auth: "admin:your-secure-password"
  # Optional: Webhook URL for receiving events
  webhook-url: ""
  # Optional: HMAC secret for webhook verification
  webhook-secret: "your-webhook-secret"
```

### Step 2: Seal the secret

```bash
kubeseal --controller-namespace kube-system \
         --controller-name sealed-secrets-controller \
         --format yaml < wa-notif-app-secret.yaml > wa-notif-app-sealed.yaml
```

### Step 3: Update secret.yaml

Replace the placeholder values in `secret.yaml` with the encrypted values from the sealed secret.

## Deployment

The application is automatically deployed via ArgoCD. After updating the sealed secrets:

1. Commit and push the changes
2. ArgoCD will sync the application
3. The database provisioning job will run
4. The Knative service will start

## Usage

### Access the Web UI

Navigate to: `https://wa-notif.benedict-aryo.com`

### QR Code Login

1. Open the web UI
2. Click "Login with QR Code"
3. Scan the QR code with your WhatsApp mobile app
4. The session will be stored persistently

### API Documentation

The API documentation is available at:
- OpenAPI spec: `https://wa-notif.benedict-aryo.com/api/docs`
- Swagger UI (if enabled): `https://wa-notif.benedict-aryo.com/swagger`

### Key API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/app/login` | GET | Get QR code for login |
| `/app/logout` | DELETE | Logout current session |
| `/send/message` | POST | Send text message |
| `/send/image` | POST | Send image message |
| `/send/document` | POST | Send document |
| `/send/video` | POST | Send video message |
| `/user/info` | GET | Get user info |
| `/user/avatar` | GET | Get user avatar |

For complete API documentation, see: [OpenAPI Specification](https://github.com/aldinokemal/go-whatsapp-web-multidevice/blob/main/docs/openapi.yaml)

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `APP_PORT` | Application port | `3000` |
| `APP_HOST` | Host address | `0.0.0.0` |
| `APP_DEBUG` | Enable debug logging | `false` |
| `APP_OS` | Device name shown in WhatsApp | `WANotif` |
| `APP_BASIC_AUTH` | Basic auth credentials | (from secret) |
| `DB_URI` | PostgreSQL connection URI | (from secret) |
| `WHATSAPP_WEBHOOK` | Webhook URL for events | (optional) |
| `WHATSAPP_WEBHOOK_SECRET` | Webhook HMAC secret | (optional) |

### Webhook Events

Available webhook events:
- `message` - Text, media, contact, location messages
- `message.reaction` - Emoji reactions
- `message.revoked` - Deleted messages
- `message.edited` - Edited messages
- `message.ack` - Delivery/read receipts
- `group.participants` - Group member events

## Monitoring

The application is monitored via ArgoCD. Access ArgoCD to view:
- Deployment status
- Pod logs
- Resource usage
- Health status

## Troubleshooting

### Common Issues

1. **Database connection failed**
   - Check if PostgreSQL is running: `kubectl get pods -n infra`
   - Verify the database URI in the secret

2. **QR code not generating**
   - Check application logs: `kubectl logs -n apps -l serving.knative.dev/service=wa-notif`
   - Ensure storage volume is properly mounted

3. **Session lost after restart**
   - Verify PVC is properly bound: `kubectl get pvc -n apps wa-notif-storages`
   - Check if session data exists in `/app/storages`

### View Logs

```bash
kubectl logs -n apps -l serving.knative.dev/service=wa-notif -f
```

### Access Pod Shell

```bash
kubectl exec -it -n apps $(kubectl get pods -n apps -l serving.knative.dev/service=wa-notif -o jsonpath='{.items[0].metadata.name}') -- /bin/sh
```

## References

- [go-whatsapp-web-multidevice GitHub](https://github.com/aldinokemal/go-whatsapp-web-multidevice)
- [Docker Image](https://github.com/aldinokemal/go-whatsapp-web-multidevice/pkgs/container/go-whatsapp-web-multidevice)
- [Webhook Payload Documentation](https://github.com/aldinokemal/go-whatsapp-web-multidevice/blob/main/docs/webhook-payload.md)
