# Deployment Verification Guide

This guide provides comprehensive verification commands to ensure your cluster is healthy and all services are running correctly.

## Quick Verification

Run the automated validation script:

```bash
./scripts/post-deployment-validation.sh
```

For detailed manual verification, continue reading.

## Cluster Health Check

### Node Status

```bash
# Set kubeconfig (run on any server node or copy kubeconfig to local machine)
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

# Verify all 5 nodes are Ready
kubectl get nodes
# Expected: 3 server nodes + 2 agent nodes, all in Ready state

# Check node details
kubectl get nodes -o wide
# Shows IP addresses, OS, kernel version, container runtime

# Verify cluster info
kubectl cluster-info
# Shows API server and CoreDNS endpoints

# Check component status
kubectl get componentstatuses
# Shows scheduler, controller-manager, etcd health
```

### Pod Status Check

```bash
# Check all pods across all namespaces
kubectl get pods -A

# Check for pods not in Running state
kubectl get pods -A --field-selector=status.phase!=Running

# Check pod resource usage
kubectl top pods -A
# Requires metrics-server (included in RKE2)

# Check for pod restarts (indicates issues)
kubectl get pods -A --sort-by='.status.containerStatuses[0].restartCount'
```

## Infrastructure Services Verification

### Longhorn (Distributed Storage)

```bash
# Check Longhorn pods
kubectl get pods -n longhorn-system
# Expected: All pods Running (longhorn-manager, longhorn-driver-deployer, etc.)

# Verify storage class
kubectl get storageclass
# Expected: longhorn (default)

# Check Longhorn volumes
kubectl get pv
# Shows persistent volumes created by Longhorn

# Access Longhorn UI (optional)
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
# Open http://localhost:8080
```

### MetalLB (Load Balancer)

```bash
# Check MetalLB pods
kubectl get pods -n metallb-system
# Expected: metallb-controller and metallb-speaker pods Running

# Verify IP address pool
kubectl get ipaddresspool -n metallb-system
# Expected: default-pool with your IP range

# Check L2 advertisement
kubectl get l2advertisement -n metallb-system
# Expected: default-l2

# Verify LoadBalancer service has external IP
kubectl get svc -n kube-system rke2-ingress-nginx-controller
# Expected: EXTERNAL-IP shows IP from MetalLB pool
```

### cert-manager (Certificate Management)

```bash
# Check cert-manager pods
kubectl get pods -n cert-manager
# Expected: cert-manager, cert-manager-cainjector, cert-manager-webhook Running

# Verify ClusterIssuer
kubectl get clusterissuer
# Expected: letsencrypt-staging Ready

# Check certificates
kubectl get certificate -A
# Shows all TLS certificates and their status

# Check certificate requests
kubectl get certificaterequest -A
# Shows certificate request history

# View certificate details
kubectl describe certificate -n <namespace> <cert-name>
```

## Application Services Verification

### MinIO (Object Storage)

```bash
# Check MinIO pods
kubectl get pods -n minio
# Expected: minio-* pod Running

# Verify MinIO service
kubectl get svc -n minio
# Expected: minio service with ClusterIP

# Check MinIO ingress
kubectl get ingress -n minio
# Expected: Ingress with minio.ljf.home and IP address

# Test MinIO API
curl -k https://minio.ljf.home/minio/health/live
# Expected: HTTP 200 OK

# Check MinIO storage
kubectl get pvc -n minio
# Expected: PVC bound to Longhorn volume
```

### ClearML (MLOps Platform)

```bash
# Check ClearML pods
kubectl get pods -n clearml
# Expected: clearml-webserver, clearml-apiserver, clearml-fileserver Running

# Verify ClearML services
kubectl get svc -n clearml
# Expected: Services for webserver, apiserver, fileserver

# Check ClearML ingresses
kubectl get ingress -n clearml
# Expected: 3 ingresses (clearml.ljf.home, api.clearml.ljf.home, files.clearml.ljf.home)

# Test ClearML web UI
curl -k https://clearml.ljf.home
# Expected: HTTP 200 with HTML content

# Test ClearML API
curl -k https://api.clearml.ljf.home/v2.0/server.info
# Expected: JSON response with server info

# Check ClearML storage
kubectl get pvc -n clearml
# Expected: PVCs for MongoDB, Elasticsearch, Redis
```

### n8n (Workflow Automation)

```bash
# Check n8n pods
kubectl get pods -n n8n
# Expected: n8n-* pod Running

# Verify n8n service
kubectl get svc -n n8n
# Expected: n8n service with ClusterIP

# Check n8n ingress
kubectl get ingress -n n8n
# Expected: Ingress with n8n.ljf.home and IP address

# Test n8n web UI
curl -k https://n8n.ljf.home
# Expected: HTTP 200 with HTML content

# Check n8n storage
kubectl get pvc -n n8n
# Expected: PVC bound to Longhorn volume
```

## Network and Ingress Verification

```bash
# Check all ingress resources
kubectl get ingress -A -o wide
# Expected: All ingresses have IP addresses assigned

# Verify ingress controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=rke2-ingress-nginx
# Expected: Ingress controller pods Running

# Check ingress controller service
kubectl get svc -n kube-system rke2-ingress-nginx-controller
# Expected: LoadBalancer service with EXTERNAL-IP from MetalLB

# Test ingress routing
curl -k -H "Host: minio.ljf.home" https://<ingress-ip>
# Should route to MinIO
```

## Storage Verification

```bash
# Check all persistent volumes
kubectl get pv
# Expected: PVs for MinIO, ClearML, n8n

# Check all persistent volume claims
kubectl get pvc -A
# Expected: All PVCs Bound

# Check storage class
kubectl get storageclass
# Expected: longhorn (default)

# Verify Longhorn replicas
kubectl get volumes.longhorn.io -n longhorn-system
# Shows volume replication status
```

## Event Log Check

```bash
# Check recent cluster events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Check events for specific namespace
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Check warning events only
kubectl get events -A --field-selector type=Warning
```

## Complete Health Check Script

Save this as `verify-cluster.sh`:

```bash
#!/bin/bash
# Complete cluster health check

export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

echo "=== Cluster Nodes ==="
kubectl get nodes

echo -e "\n=== Pod Status ==="
kubectl get pods -A | grep -v Running | grep -v Completed

echo -e "\n=== Ingress Resources ==="
kubectl get ingress -A

echo -e "\n=== Certificates ==="
kubectl get certificate -A

echo -e "\n=== Storage ==="
kubectl get pv
kubectl get pvc -A

echo -e "\n=== Recent Events ==="
kubectl get events -A --sort-by='.lastTimestamp' | tail -10

echo -e "\n=== Service Endpoints ==="
echo "MinIO: https://minio.ljf.home"
echo "ClearML: https://clearml.ljf.home"
echo "n8n: https://n8n.ljf.home"
```

## Expected Deployment State

After successful deployment, you should see:

- ✅ 5 nodes in Ready state (3 servers + 2 agents)
- ✅ All pods in Running state (no CrashLoopBackOff or Error)
- ✅ All PVCs Bound to PVs
- ✅ All ingresses have IP addresses assigned
- ✅ All certificates in Ready state
- ✅ No Warning events related to deployment
- ✅ Services accessible via HTTPS URLs

## Next Steps

- Configure DNS and access services: [Service Access Guide](SERVICE-ACCESS.md)
- Test service accessibility: [Testing Guide](TESTING.md)
- Learn about maintenance: [Maintenance Guide](MAINTENANCE.md)
