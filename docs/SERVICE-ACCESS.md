# Service Access Configuration

This guide explains how to configure DNS and access deployed services.

## Overview

After deployment, services are accessible via HTTPS with domain names. You need to configure DNS resolution to access them.

## Step 1: Get the Ingress IP Address

```bash
# Set kubeconfig
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

# Get ingress IP (assigned by MetalLB)
kubectl get ingress -A -o wide

# Or get the LoadBalancer service IP
kubectl get svc -n kube-system rke2-ingress-nginx-controller

# Example output:
# NAME                              CLASS   HOSTS                 ADDRESS         PORTS
# minio-ingress                     nginx   minio.ljf.home        172.16.86.200   80, 443
# clearml-webserver-ingress         nginx   clearml.ljf.home      172.16.86.200   80, 443
# ...
```

The `ADDRESS` column shows your ingress IP (e.g., `172.16.86.200`).

## Step 2: Configure DNS Resolution

Choose one of the following methods:

### Option A: Local DNS Server (Recommended for Production)

If you have a local DNS server (e.g., Pi-hole, dnsmasq, BIND):

1. **Add A records** for each service:

```
minio.ljf.home              A    172.16.86.200
clearml.ljf.home            A    172.16.86.200
api.clearml.ljf.home        A    172.16.86.200
files.clearml.ljf.home      A    172.16.86.200
n8n.ljf.home                A    172.16.86.200
```

2. **Or use wildcard DNS** (simpler):

```
*.ljf.home                  A    172.16.86.200
```

3. **Configure clients** to use your DNS server.

### Option B: /etc/hosts File (Quick Testing)

For testing or small deployments, add entries to `/etc/hosts` on client machines:

**Linux/macOS**:

```bash
# Edit /etc/hosts (requires sudo)
sudo nano /etc/hosts

# Add these lines (replace 172.16.86.200 with your ingress IP)
172.16.86.200 minio.ljf.home
172.16.86.200 clearml.ljf.home
172.16.86.200 api.clearml.ljf.home
172.16.86.200 files.clearml.ljf.home
172.16.86.200 n8n.ljf.home
```

**Windows**:

```powershell
# Edit C:\Windows\System32\drivers\etc\hosts (requires Administrator)
notepad C:\Windows\System32\drivers\etc\hosts

# Add these lines (replace 172.16.86.200 with your ingress IP)
172.16.86.200 minio.ljf.home
172.16.86.200 clearml.ljf.home
172.16.86.200 api.clearml.ljf.home
172.16.86.200 files.clearml.ljf.home
172.16.86.200 n8n.ljf.home
```

### Option C: Router DNS Override

Some routers allow DNS overrides:

1. Access router admin interface
2. Navigate to DNS settings
3. Add static DNS entries for `*.ljf.home` → `172.16.86.200`

## Step 3: Verify DNS Resolution

```bash
# Test DNS resolution
nslookup minio.ljf.home
ping minio.ljf.home

# Test HTTPS access (ignore certificate warnings for staging)
curl -k https://minio.ljf.home
curl -k https://clearml.ljf.home
curl -k https://n8n.ljf.home
```

## Service URLs and Credentials

Once DNS is configured, access services at:

### MinIO (Object Storage)

- **URL**: <https://minio.ljf.home>
- **Username**: `admin`
- **Password**: Value from `vault_minio_root_pass` in `vars/secrets.yml`
- **Purpose**: S3-compatible storage for ML artifacts, datasets, models

### ClearML (MLOps Platform)

- **Web UI**: <https://clearml.ljf.home>
- **API Server**: <https://api.clearml.ljf.home>
- **File Server**: <https://files.clearml.ljf.home>
- **Default Credentials**: No authentication required (configure in ClearML settings)
- **Purpose**: Experiment tracking, model registry, pipeline orchestration

### n8n (Workflow Automation)

- **URL**: <https://n8n.ljf.home>
- **Username**: `admin`
- **Password**: Value from `vault_n8n_admin_pass` in `vars/secrets.yml`
- **Purpose**: Workflow automation, ML pipeline orchestration

## Certificate Warnings

**Expected Behavior**: The deployment uses Let's Encrypt **staging** environment by default.

- ✅ Browsers will show certificate warnings (this is normal)
- ✅ Click "Advanced" → "Proceed to site" to access services
- ✅ Use `curl -k` flag to ignore certificate warnings in CLI

**For Production**: Switch to Let's Encrypt production issuer (see [Maintenance Guide](MAINTENANCE.md) → Certificate Renewal section).

## Troubleshooting Access Issues

### Cannot resolve domain names

```bash
# Check DNS resolution
nslookup minio.ljf.home

# If fails, verify /etc/hosts entries or DNS server configuration
cat /etc/hosts | grep ljf.home
```

### Connection refused

```bash
# Verify ingress has IP assigned
kubectl get ingress -A

# Check ingress controller is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=rke2-ingress-nginx

# Verify MetalLB assigned IP
kubectl get svc -n kube-system rke2-ingress-nginx-controller
```

### Certificate errors (other than staging warning)

```bash
# Check certificate status
kubectl get certificate -A

# View certificate details
kubectl describe certificate -n <namespace> <cert-name>

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```

## Testing Service Accessibility

Use the automated test script:

```bash
./scripts/service-accessibility-test.sh
```

See [Testing Guide](TESTING.md) for details.
