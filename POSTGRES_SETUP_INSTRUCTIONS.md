# PostgreSQL Setup Instructions

## Issue Description

There are two related issues with the PostgreSQL database provisioning:

1. **Shared Resource Conflict**: Originally, both wa-notif and blog applications had SealedSecrets named "postgres-admin" in the same namespace (apps), causing an ArgoCD conflict.

2. **SealedSecrets Cross-Namespace Issue**: The encrypted values in the SealedSecrets were encrypted for the "infra" namespace but are being used in the "apps" namespace. Due to SealedSecrets' namespace scoping, these encrypted values cannot be decrypted in the apps namespace.

## Current Status

✅ **Fixed**: The shared resource conflict has been resolved by renaming the SealedSecrets:
- `postgres-admin` → `wa-notif-postgres-admin` (in wa-notif app)
- `postgres-admin` → `blog-postgres-admin` (in blog app)

❌ **Still Needs Fix**: The SealedSecrets in the apps namespace have encrypted values that were copied from the infra namespace and will not decrypt properly.

## Solution Required

To fix the SealedSecrets decryption issue, you need to regenerate the encrypted values specifically for the apps namespace:

### Step 1: Generate new SealedSecrets for wa-notif app

```bash
# Create a temporary secret manifest for wa-notif
cat <<EOF > wa-notif-postgres-admin-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: wa-notif-postgres-admin
  namespace: apps
data:
  postgres-password: $(echo -n 'YOUR_POSTGRES_ADMIN_PASSWORD' | base64)
EOF

# Seal the secret for the apps namespace
kubeseal --format yaml --namespace apps --name wa-notif-postgres-admin < wa-notif-postgres-admin-secret.yaml > sealed-wa-notif-postgres-admin.yaml

# Replace the encrypted value in apps/wa-notif/postgres-values.yaml with the content from sealed-wa-notif-postgres-admin.yaml
```

### Step 2: Generate new SealedSecrets for blog app

```bash
# Create a temporary secret manifest for blog
cat <<EOF > blog-postgres-admin-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: blog-postgres-admin
  namespace: apps
data:
  postgres-password: $(echo -n 'YOUR_POSTGRES_ADMIN_PASSWORD' | base64)
EOF

# Seal the secret for the apps namespace
kubeseal --format yaml --namespace apps --name blog-postgres-admin < blog-postgres-admin-secret.yaml > sealed-blog-postgres-admin.yaml

# Replace the encrypted value in apps/blog/postgres-values.yaml with the content from sealed-blog-postgres-admin.yaml
```

### Step 3: Apply the changes

After updating the encrypted values in the postgres-values.yaml files:

```bash
# Delete the existing jobs to force recreation
kubectl delete job wa-notif-db-provision -n apps
kubectl delete job blog-db-provision -n apps

# Wait for ArgoCD to sync the changes
```

## Alternative Approach

If you want to avoid managing separate admin passwords, you could:

1. Create a single admin secret in the apps namespace
2. Have both applications reference that same secret
3. Remove the individual database provisioning jobs and create databases/users manually or through a centralized process

## Verification

After applying the fixes, verify that:

1. The SealedSecrets are properly decrypted:
   ```bash
   kubectl get secrets -n apps | grep postgres-admin
   ```

2. The database provisioning jobs complete successfully:
   ```bash
   kubectl get jobs -n apps
   kubectl logs job/wa-notif-db-provision -n apps
   kubectl logs job/blog-db-provision -n apps
   ```