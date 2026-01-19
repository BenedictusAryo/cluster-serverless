# WhatsApp Notification Service

A serverless WhatsApp Web gateway based on [aldinokemal/go-whatsapp-web-multidevice](https://github.com/aldinokemal/go-whatsapp-web-multidevice). This service allows you to interact with WhatsApp via a REST API, supporting message sending, media handling, and webhook notifications.

## 🚀 Deployment Overview

- **Platform**: Knative Service (Serverless)
- **Namespace**: `apps`
- **Domain**: [https://wa-notif.benedict-aryo.com](https://wa-notif.benedict-aryo.com)
- **Infrastructure**: Shared PostgreSQL (`infra` namespace) with dedicated persistence for session storage.

## ⚙️ Configuration Parameters

The application is configured via environment variables sourced from `SealedSecrets`.

| Parameter | Key in Secret | Description |
| :--- | :--- | :--- |
| **Basic Auth** | `basic-auth` | Web UI/API protection (format: `username:password`) |
| **Database URI** | `database-uri` | Connection string for the shared PostgreSQL instance |
| **Webhook URL** | `webhook-url` | Destination for incoming message notifications |
| **Webhook Secret** | `webhook-secret` | Security handshake key sent in webhook headers |

## 💾 Persistence & Database

### Session & Cache Storage (`/app/storages`)
Even though the application uses PostgreSQL as its primary database, it maintains a **hybrid storage architecture**:

- **PostgreSQL**: Stores core application data, schema versioning, and service-level configurations.
- **Local SQLite (`chatstorage.db`)**: The application uses a local SQLite database within the storage volume to cache chat history, message states, and temporary session blobs. 
- **Purpose**: Without this persistent volume, the application would "forget" your login pairing and chat cache every time the Knative service scales to zero or restarts. The sessions are tied to the files in this directory.
- **Implementation**: We use a **1Gi PersistentVolumeClaim** (`wa-notif-storages`) mounted at `/app/storages`.
- **Why 1Gi?**: While the main data is in Postgres, the local SQLite cache and paired device secrets can grow over time. 1Gi provides a safe buffer for these files and potential media logs.
- **Usage**: The app manages these files automatically. Clearing this volume will effectively logout all active WhatsApp sessions.

### Database Setup
The database is provisioned automatically via the `wa-notif-db-provision` Kubernetes Job.
- **Database Name**: `wa-notif`
- **Database User**: `wa-notif`
- **Host**: `postgres.infra.svc.cluster.local`

## 🔐 Changing Credentials (GitOps Workflow)

Secrets are encrypted using **Bitnami SealedSecrets**. To update the username, password, or webhook settings, use this one-line command to generate the manifest for Git:

```bash
kubectl create secret opaque wa-notif-secrets \
  --namespace apps \
  --from-literal=basic-auth='admin:YOUR_NEW_PASSWORD' \
  --from-literal=webhook-secret='your_key' \
  --from-literal=webhook-url='https://your-api.com/callback' \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace kube-system --controller-name sealed-secrets-controller -o yaml > apps/wa-notif/secret.yaml
```

> **Note**: Always wrap your secret values in **single quotes (`'`)** as shown above. This prevents the terminal shell from misinterpreting special characters like `$`, `!`, or `*`.

After running the command, **commit and push** the changes to GitHub. Argo CD will sync the secret, and you should update the `redeploy-timestamp` in `values.yaml` to trigger a fresh rollout.

## 📖 Usage Guide

Once logged in via the browser, you will see the dashboard where you can pair your device by scanning the QR code.

### API Endpoints
The service follows the standard API structure of the upstream project:
- `GET /` - Dashboard / Session status
- `GET /api/devices` - List connected devices / Get QR Code
- `POST /api/send-message` - Send text messages
- `POST /api/send-image` - Send media files

For full API documentation (Swagger), you can usually visit `/swagger/index.html` on your deployment or refer to the [upstream documentation](https://github.com/aldinokemal/go-whatsapp-web-multidevice).
