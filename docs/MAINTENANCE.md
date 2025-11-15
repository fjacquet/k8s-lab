# Maintenance Guide

This guide covers common maintenance operations for your RKE2 cluster.

## Adding Nodes

### Adding an Agent Node

Increases worker capacity for running workloads.

1. **Prepare the new node**:

   - Install Ubuntu 24.04 LTS
   - Configure static IP address
   - Set up SSH access with the same user as other nodes
   - Configure passwordless sudo

2. **Update inventory**:

```yaml
# inventory.yml
rke2_agents:
  hosts:
    opt4:
      ansible_host: 172.16.86.104
    opt5:
      ansible_host: 172.16.86.105
    opt6: # New agent node
      ansible_host: 172.16.86.106
```

3. **Test connectivity**:

```bash
ansible opt6 -m ping
```

4. **Deploy to new node only**:

```bash
ansible-playbook playbook.yml --limit opt6 --ask-vault-pass
```

5. **Verify node joined**:

```bash
kubectl get nodes
# Should show opt6 in Ready state
```

### Adding a Server Node

Increases control plane HA (only add to maintain odd numbers: 3, 5, 7).

1. Follow same process as agent node
2. Add to `rke2_servers` group instead
3. Update `tls-san` list in `rke2_server_config` with new server IP

## Removing Nodes

### Graceful Node Removal

1. **Drain the node** (move workloads to other nodes):

```bash
kubectl drain <optname> --ignore-daemonsets --delete-emptydir-data
```

2. **Delete the node from cluster**:

```bash
kubectl delete node <optname>
```

3. **Remove from inventory**:

```yaml
# Remove node entry from inventory.yml
```

4. **Clean up node** (optional, on the removed node):

```bash
# Stop RKE2 service
sudo systemctl stop rke2-server  # or rke2-agent
sudo systemctl disable rke2-server  # or rke2-agent

# Remove RKE2 data
sudo rm -rf /var/lib/rancher/rke2
sudo rm -rf /etc/rancher/rke2
```

## Upgrading RKE2

**Important**: Always upgrade server nodes before agent nodes.

### Upgrade Procedure

1. **Check current version**:

```bash
kubectl get nodes -o wide
# Check VERSION column
```

2. **Update version in inventory**:

```yaml
# inventory.yml
vars:
  rke2_version: "v1.29.0+rke2r1" # New version
```

3. **Upgrade server nodes first**:

```bash
ansible-playbook playbook.yml --limit rke2_servers --ask-vault-pass
```

4. **Verify server nodes**:

```bash
kubectl get nodes
# Verify all server nodes show new version
```

5. **Upgrade agent nodes**:

```bash
ansible-playbook playbook.yml --limit rke2_agents --ask-vault-pass
```

6. **Verify cluster health**:

```bash
kubectl get nodes
kubectl get pods -A
```

**Rollback**: If upgrade fails, revert `rke2_version` and re-run playbook.

## Updating Service Credentials

### MinIO Password

1. **Edit encrypted secrets**:

```bash
ansible-vault edit vars/secrets.yml
# Update vault_minio_root_pass
```

2. **Re-deploy MinIO**:

```bash
ansible-playbook playbook.yml --tags applications --ask-vault-pass
```

3. **Verify new credentials**:

```bash
# Login to MinIO with new password
curl -k https://minio.ljf.home
```

### n8n Password

1. **Edit encrypted secrets**:

```bash
ansible-vault edit vars/secrets.yml
# Update vault_n8n_admin_pass
```

2. **Re-deploy n8n**:

```bash
ansible-playbook playbook.yml --tags applications --ask-vault-pass
```

## Updating Application Versions

### Update Service Versions

1. **Edit role defaults**:

```bash
# Edit roles/k8s_apps/defaults/main.yml
# Update chart versions
```

2. **Re-run application phase**:

```bash
ansible-playbook playbook.yml --tags applications --ask-vault-pass
```

3. **Verify updates**:

```bash
helm list -A
kubectl get pods -A
```

## Backup and Recovery

### Backup etcd (Critical for Cluster State)

```bash
# On any server node
kubectl -n kube-system exec etcd-opt1 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/rke2/server/tls/etcd/server-client.key \
  snapshot save /tmp/etcd-snapshot-$(date +%Y%m%d-%H%M%S).db

# Copy snapshot to safe location
kubectl cp kube-system/etcd-opt1:/tmp/etcd-snapshot-*.db ./backups/
```

### Backup Persistent Volumes (via Longhorn)

```bash
# Access Longhorn UI
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80

# Open http://localhost:8080
# Navigate to Volume → Select volume → Create Snapshot
# Create recurring snapshots for automated backups
```

### Backup Helm Values

```bash
# Backup all Helm release values
helm list -A --output json | jq -r '.[] | "\(.name) \(.namespace)"' | \
while read name namespace; do
  helm get values $name -n $namespace > backups/${name}-values.yaml
done
```

### Restore from Backup

```bash
# Restore etcd (requires cluster rebuild)
# See RKE2 documentation for etcd restore procedures

# Restore Longhorn volumes
# Use Longhorn UI to restore from snapshots

# Restore Helm releases
helm upgrade <release-name> <chart> -n <namespace> -f backups/<release>-values.yaml
```

## Certificate Management

### Certificate Renewal

Certificates are automatically renewed by cert-manager 30 days before expiration.

**Check certificate status**:

```bash
kubectl get certificate -A
kubectl describe certificate -n <namespace> <cert-name>
```

**Force certificate renewal**:

```bash
# Delete certificate secret to trigger renewal
kubectl delete secret <cert-secret-name> -n <namespace>

# cert-manager will automatically request new certificate
```

### Switch to Let's Encrypt Production

The deployment uses Let's Encrypt **staging** by default. To switch to production:

1. **Edit ClusterIssuer** in `roles/k8s_apps/tasks/main.yml`:

```yaml
server: https://acme-v02.api.letsencrypt.org/directory # Production
```

2. **Update ingress annotations** to use production issuer:

```yaml
cert-manager.io/cluster-issuer: "letsencrypt-production"
```

3. **Re-run infrastructure phase**:

```bash
ansible-playbook playbook.yml --tags infrastructure --ask-vault-pass
```

4. **Delete existing certificates** to trigger re-issuance:

```bash
kubectl delete certificate -A --all
```

## Monitoring and Health Checks

### Regular Health Checks

```bash
# Check node status
kubectl get nodes

# Check pod status
kubectl get pods -A

# Check storage
kubectl get pv
kubectl get pvc -A

# Check certificates
kubectl get certificate -A

# Check recent events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

### Automated Monitoring

Run the verification script regularly:

```bash
# Add to cron for daily checks
0 8 * * * /path/to/scripts/post-deployment-validation.sh
```

## Troubleshooting Common Issues

### Pod Stuck in Pending

```bash
# Check pod events
kubectl describe pod -n <namespace> <pod-name>

# Check node resources
kubectl top nodes

# Check PVC status
kubectl get pvc -n <namespace>
```

### Service Not Accessible

```bash
# Check ingress
kubectl get ingress -A

# Check ingress controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=rke2-ingress-nginx

# Check MetalLB
kubectl get pods -n metallb-system
```

### Certificate Issues

```bash
# Check certificate status
kubectl get certificate -A

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check certificate requests
kubectl get certificaterequest -A
```

For more troubleshooting, see [Troubleshooting Guide](TROUBLESHOOTING.md).

## Maintenance Schedule

### Daily

- Monitor service accessibility
- Check for pod restarts
- Review cluster events

### Weekly

- Run post-deployment validation
- Check storage usage
- Review certificate expiration dates

### Monthly

- Test backup and restore procedures
- Review and update service versions
- Test idempotency
- Review security updates

### Quarterly

- Plan RKE2 version upgrades
- Review and update documentation
- Audit access credentials
- Test disaster recovery procedures

## Next Steps

- Learn about troubleshooting: [Troubleshooting Guide](TROUBLESHOOTING.md)
- Review testing procedures: [Testing Guide](TESTING.md)
- Understand the architecture: [Architecture Guide](ARCHITECTURE.md)
