# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the RKE2 Lab Automation deployment.

## Connection Issues

### SSH Connection Failures

**Symptoms**: `ansible all -m ping` fails

**Diagnosis**:

```bash
# Test SSH connectivity manually
ssh ubuntu@172.16.86.101

# Check SSH configuration
ansible all -m setup -a "filter=ansible_ssh_*"

# Verify sudo access
ansible all -m shell -a "sudo whoami" --become
```

**Solutions**:

1. **Verify SSH key**:

```bash
# Check SSH key exists
ls -la ~/.ssh/id_rsa

# Add key to ssh-agent
ssh-add ~/.ssh/id_rsa
```

2. **Check inventory configuration**:

```yaml
# Ensure correct user and key path
ansible_user: ubuntu
ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

3. **Verify passwordless sudo**:

```bash
# On target node
sudo visudo
# Add: ubuntu ALL=(ALL) NOPASSWD:ALL
```

### Network Connectivity Issues

**Symptoms**: Cannot reach nodes from control machine

**Diagnosis**:

```bash
# Test network connectivity
ping 172.16.86.101

# Check routing
traceroute 172.16.86.101

# Verify firewall rules
ansible all -m shell -a "sudo ufw status"
```

**Solutions**:

1. **Check firewall rules**:

```bash
# Allow SSH on target nodes
sudo ufw allow 22/tcp
sudo ufw enable
```

2. **Verify network configuration**:

```bash
# Check IP addresses
ip addr show

# Check routing table
ip route show
```

## RKE2 Issues

### RKE2 Service Won't Start

**Symptoms**: RKE2 service fails to start or crashes

**Diagnosis**:

```bash
# Check RKE2 service status
ansible rke2_servers -m shell -a "systemctl status rke2-server"
ansible rke2_agents -m shell -a "systemctl status rke2-agent"

# View RKE2 logs
ansible rke2_servers -m shell -a "journalctl -u rke2-server -n 50"
ansible rke2_agents -m shell -a "journalctl -u rke2-agent -n 50"
```

**Common Causes**:

1. **Swap not disabled**:

```bash
# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

2. **Port conflicts**:

```bash
# Check if ports are in use
sudo netstat -tulpn | grep -E '6443|9345|10250'
```

3. **Insufficient resources**:

```bash
# Check memory and disk
free -h
df -h
```

### Agent Nodes Won't Join Cluster

**Symptoms**: Agent nodes fail to join the cluster

**Diagnosis**:

```bash
# Check agent logs
journalctl -u rke2-agent -n 100

# Verify server is reachable
curl -k https://172.16.86.101:9345
```

**Solutions**:

1. **Verify token**:

```bash
# On server node
cat /var/lib/rancher/rke2/server/opttoken

# Ensure token matches in agent config
cat /etc/rancher/rke2/config.yaml
```

2. **Check server URL**:

```yaml
# Agent config should point to server
server: https://172.16.86.101:9345
```

3. **Verify network connectivity**:

```bash
# From agent node
telnet 172.16.86.101 9345
```

## Kubernetes Issues

### Pods Stuck in Pending

**Symptoms**: Pods remain in Pending state

**Diagnosis**:

```bash
# Check pod status
kubectl get pods -A

# Describe pod for events
kubectl describe pod -n <namespace> <pod-name>

# Check node resources
kubectl top nodes
kubectl describe nodes
```

**Common Causes**:

1. **Insufficient resources**:

```bash
# Check node capacity
kubectl describe nodes | grep -A 5 "Allocated resources"
```

2. **PVC not bound**:

```bash
# Check PVC status
kubectl get pvc -A

# Check storage class
kubectl get storageclass
```

3. **Node selector mismatch**:

```bash
# Check pod node selector
kubectl get pod -n <namespace> <pod-name> -o yaml | grep -A 5 nodeSelector

# Check node labels
kubectl get nodes --show-labels
```

### Pods CrashLoopBackOff

**Symptoms**: Pods continuously restart

**Diagnosis**:

```bash
# Check pod logs
kubectl logs -n <namespace> <pod-name>

# Check previous container logs
kubectl logs -n <namespace> <pod-name> --previous

# Describe pod for events
kubectl describe pod -n <namespace> <pod-name>
```

**Solutions**:

1. **Check resource limits**:

```bash
# View pod resource requests/limits
kubectl get pod -n <namespace> <pod-name> -o yaml | grep -A 10 resources
```

2. **Check configuration**:

```bash
# View pod environment variables
kubectl get pod -n <namespace> <pod-name> -o yaml | grep -A 20 env

# Check ConfigMaps and Secrets
kubectl get configmap -n <namespace>
kubectl get secret -n <namespace>
```

3. **Check dependencies**:

```bash
# Ensure dependent services are running
kubectl get pods -n <namespace>
kubectl get svc -n <namespace>
```

### Service Not Accessible

**Symptoms**: Cannot access service via ClusterIP or LoadBalancer

**Diagnosis**:

```bash
# Check service
kubectl get svc -n <namespace>

# Check endpoints
kubectl get endpoints -n <namespace>

# Check pod labels match service selector
kubectl get pod -n <namespace> --show-labels
kubectl get svc -n <namespace> -o yaml | grep -A 5 selector
```

**Solutions**:

1. **Verify pod is running**:

```bash
kubectl get pods -n <namespace>
```

2. **Check service selector**:

```bash
# Service selector must match pod labels
kubectl describe svc -n <namespace> <service-name>
```

3. **Test from within cluster**:

```bash
# Create test pod
kubectl run test --image=busybox -it --rm -- sh
# Inside pod:
wget -O- http://<service-name>.<namespace>.svc.cluster.local
```

## Helm Issues

### Helm Release Failed

**Symptoms**: Helm install or upgrade fails

**Diagnosis**:

```bash
# List Helm releases
helm list -A

# Check release status
helm status <release-name> -n <namespace>

# View release history
helm history <release-name> -n <namespace>

# Get release values
helm get values <release-name> -n <namespace>
```

**Solutions**:

1. **Rollback release**:

```bash
helm rollback <release-name> -n <namespace>
```

2. **Uninstall and reinstall**:

```bash
helm uninstall <release-name> -n <namespace>
# Wait for resources to be deleted
kubectl get all -n <namespace>
# Reinstall
ansible-playbook playbook.yml --tags applications --ask-vault-pass
```

3. **Check chart values**:

```bash
# Validate values file
helm template <release-name> <chart> -f values.yaml
```

## Storage Issues

### PVC Stuck in Pending

**Symptoms**: PersistentVolumeClaim remains in Pending state

**Diagnosis**:

```bash
# Check PVC status
kubectl get pvc -A

# Describe PVC for events
kubectl describe pvc -n <namespace> <pvc-name>

# Check storage class
kubectl get storageclass

# Check Longhorn status
kubectl get pods -n longhorn-system
```

**Solutions**:

1. **Verify Longhorn is running**:

```bash
kubectl get pods -n longhorn-system
# All pods should be Running
```

2. **Check storage class**:

```bash
# Ensure default storage class exists
kubectl get storageclass
# Should show longhorn with (default)
```

3. **Check node storage**:

```bash
# Verify nodes have available disk space
kubectl get nodes
ansible all -m shell -a "df -h"
```

### Longhorn Volume Issues

**Symptoms**: Longhorn volumes degraded or unavailable

**Diagnosis**:

```bash
# Check Longhorn volumes
kubectl get volumes.longhorn.io -n longhorn-system

# Check Longhorn replicas
kubectl get replicas.longhorn.io -n longhorn-system

# Access Longhorn UI
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
# Open http://localhost:8080
```

**Solutions**:

1. **Check node disk space**:

```bash
ansible all -m shell -a "df -h /var/lib/longhorn"
```

2. **Verify iSCSI is running**:

```bash
ansible all -m shell -a "systemctl status iscsid"
```

3. **Restart Longhorn components**:

```bash
kubectl rollout restart deployment -n longhorn-system
```

## Network and Ingress Issues

### Ingress Not Getting IP Address

**Symptoms**: Ingress resources don't have EXTERNAL-IP assigned

**Diagnosis**:

```bash
# Check ingress resources
kubectl get ingress -A

# Check MetalLB pods
kubectl get pods -n metallb-system

# Check MetalLB configuration
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system

# Check ingress controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=rke2-ingress-nginx
```

**Solutions**:

1. **Verify MetalLB is running**:

```bash
kubectl get pods -n metallb-system
# controller and speaker pods should be Running
```

2. **Check IP pool configuration**:

```bash
kubectl describe ipaddresspool -n metallb-system default-pool
# Verify IP range is correct
```

3. **Check ingress controller service**:

```bash
kubectl get svc -n kube-system rke2-ingress-nginx-controller
# Should have EXTERNAL-IP from MetalLB pool
```

### Cannot Access Services via Domain

**Symptoms**: Services not accessible via configured domain names

**Diagnosis**:

```bash
# Test DNS resolution
nslookup minio.ljf.home

# Test direct IP access
curl -k https://<ingress-ip>

# Test with Host header
curl -k -H "Host: minio.ljf.home" https://<ingress-ip>

# Check ingress configuration
kubectl get ingress -n <namespace> -o yaml
```

**Solutions**:

1. **Configure DNS or /etc/hosts**:

```bash
# Add to /etc/hosts
echo "172.16.86.200 minio.ljf.home" | sudo tee -a /etc/hosts
```

2. **Verify ingress rules**:

```bash
kubectl describe ingress -n <namespace> <ingress-name>
```

3. **Check ingress controller logs**:

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=rke2-ingress-nginx
```

## Certificate Issues

### Certificates Not Issuing

**Symptoms**: Certificates stuck in Pending or False state

**Diagnosis**:

```bash
# Check certificate status
kubectl get certificate -A

# Describe certificate
kubectl describe certificate -n <namespace> <cert-name>

# Check certificate requests
kubectl get certificaterequest -A

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager

# Check ClusterIssuer
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-staging
```

**Solutions**:

1. **Verify cert-manager is running**:

```bash
kubectl get pods -n cert-manager
# All pods should be Running
```

2. **Check ACME challenge**:

```bash
# View challenges
kubectl get challenges -A

# Describe challenge
kubectl describe challenge -n <namespace> <challenge-name>
```

3. **Verify DNS/HTTP accessibility**:

```bash
# Ensure domain is accessible from internet (for Let's Encrypt)
curl http://<domain>/.well-known/acme-challenge/test
```

4. **Delete and recreate certificate**:

```bash
kubectl delete certificate -n <namespace> <cert-name>
# cert-manager will recreate automatically
```

## Application-Specific Issues

### MinIO Not Accessible

**Diagnosis**:

```bash
# Check MinIO pods
kubectl get pods -n minio

# Check MinIO logs
kubectl logs -n minio -l app=minio

# Check MinIO service
kubectl get svc -n minio

# Test MinIO health
curl -k https://minio.ljf.home/minio/health/live
```

### ClearML Not Working

**Diagnosis**:

```bash
# Check all ClearML pods
kubectl get pods -n clearml

# Check specific component logs
kubectl logs -n clearml -l app=clearml-webserver
kubectl logs -n clearml -l app=clearml-apiserver
kubectl logs -n clearml -l app=clearml-fileserver

# Check ClearML services
kubectl get svc -n clearml

# Check ClearML ingresses
kubectl get ingress -n clearml
```

### n8n Not Starting

**Diagnosis**:

```bash
# Check n8n pod
kubectl get pods -n n8n

# Check n8n logs
kubectl logs -n n8n -l app=n8n

# Check n8n PVC
kubectl get pvc -n n8n

# Check n8n service
kubectl get svc -n n8n
```

## Ansible Playbook Issues

### Playbook Fails on Specific Task

**Diagnosis**:

```bash
# Run with verbose output
ansible-playbook playbook.yml -vvv --ask-vault-pass

# Run in check mode
ansible-playbook playbook.yml --check --ask-vault-pass

# Run specific tags
ansible-playbook playbook.yml --tags common --ask-vault-pass
```

**Solutions**:

1. **Check syntax**:

```bash
ansible-playbook playbook.yml --syntax-check
```

2. **Lint playbook**:

```bash
ansible-lint playbook.yml
```

3. **Run on specific host**:

```bash
ansible-playbook playbook.yml --limit opt1 --ask-vault-pass
```

### Vault Password Issues

**Symptoms**: Cannot decrypt secrets

**Solutions**:

```bash
# Verify vault file is encrypted
cat vars/secrets.yml

# Test vault password
ansible-vault view vars/secrets.yml

# Rekey vault with new password
ansible-vault rekey vars/secrets.yml
```

## Getting Help

### Collect Diagnostic Information

```bash
# Cluster info
kubectl cluster-info dump > cluster-dump.txt

# Node status
kubectl get nodes -o wide > nodes.txt

# All pods
kubectl get pods -A -o wide > pods.txt

# All events
kubectl get events -A --sort-by='.lastTimestamp' > events.txt

# Service status
kubectl get svc -A > services.txt

# Ingress status
kubectl get ingress -A > ingress.txt
```

### Run Validation Scripts

```bash
# Pre-deployment test
./scripts/pre-deployment-test.sh

# Post-deployment validation
./scripts/post-deployment-validation.sh

# Service accessibility test
./scripts/service-accessibility-test.sh
```

### Check Logs

```bash
# Ansible logs
# (saved during playbook run)

# RKE2 logs
journalctl -u rke2-server -n 100
journalctl -u rke2-agent -n 100

# Kubernetes component logs
kubectl logs -n kube-system <pod-name>
```

## References

- [RKE2 Troubleshooting](https://docs.rke2.io/troubleshooting/)
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug/)
- [Longhorn Troubleshooting](https://longhorn.io/docs/latest/troubleshooting/)
- [MetalLB Troubleshooting](https://metallb.universe.tf/troubleshooting/)
- [Cert-manager Troubleshooting](https://cert-manager.io/docs/troubleshooting/)
- [Ansible Troubleshooting](https://docs.ansible.com/ansible/latest/user_guide/playbooks_startnstep.html)
