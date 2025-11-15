# k8s_apps

Deploys infrastructure and application services to an RKE2 Kubernetes cluster in two phases:

- **Infrastructure Phase**: Longhorn, MetalLB, cert-manager, ingress configuration
- **Applications Phase**: MinIO, ClearML, n8n

## Status

⚠️ **UNDER DEVELOPMENT** - Currently placeholder implementation only.

**Completed:**

- Role structure created
- Phase-based deployment pattern established
- Default variables defined for all services

**Pending Implementation:**

- Task 4: Infrastructure services deployment (Longhorn, MetalLB, cert-manager)
- Task 5: Application services deployment (MinIO, ClearML, n8n)

## Requirements

- RKE2 cluster already deployed and operational (3 server nodes + 2 agent nodes)
- `kubernetes.core` Ansible collection installed (>= 3.0.0)
- kubectl access configured (kubeconfig at /etc/rancher/rke2/rke2.yaml)
- Helm 3 installed on control node or target node
- Target execution on first server node only (rke2_servers[0])
- Ubuntu 24.04 LTS on all nodes
- open-iscsi package installed (required for Longhorn)

## Role Variables

### Required Variables

```yaml
deployment_phase: infrastructure # or 'applications' - MUST be set when calling role
```

### Infrastructure Phase Variables

Defined in `defaults/main.yml`:

```yaml
# Longhorn - Distributed block storage
longhorn_version: "1.6.0"
longhorn_namespace: "longhorn-system"

# MetalLB - Bare-metal load balancer
metallb_version: "0.14.3"
metallb_namespace: "metallb-system"
# metallb_ip_range: defined in inventory.yml (e.g., "172.16.86.200-172.16.86.210")

# cert-manager - Certificate management
certmanager_version: "v1.14.2"
certmanager_namespace: "cert-manager"
certmanager_letsencrypt_server: "https://acme-staging-v02.api.letsencrypt.org/directory"
# acme_email: defined in inventory.yml
# domain: defined in inventory.yml (e.g., "ljf.home")
```

### Application Phase Variables

Defined in `defaults/main.yml`:

```yaml
# MinIO - S3-compatible object storage
minio_version: "5.0.15"
minio_namespace: "minio"
minio_storage_size: "50Gi"
# minio_root_user: defined in inventory.yml
# minio_root_pass: defined in inventory.yml (references vault_minio_root_pass)

# ClearML - MLOps platform
clearml_version: "7.4.0"
clearml_namespace: "clearml"
clearml_storage_size: "20Gi"

# n8n - Workflow automation
n8n_version: "0.234.0"
n8n_namespace: "n8n"
n8n_storage_size: "5Gi"
# n8n_admin_user: defined in inventory.yml
# n8n_admin_pass: defined in inventory.yml (references vault_n8n_admin_pass)
```

### Kubernetes Configuration

```yaml
kubeconfig_path: "/etc/rancher/rke2/rke2.yaml"
kubectl_bin: "/var/lib/rancher/rke2/bin/kubectl"
helm_bin: "/usr/local/bin/helm"
```

## Dependencies

- `kubernetes.core` collection (>= 3.0.0)
- RKE2 cluster must be deployed first (via lablabs.rke2 role)
- Requires kubeconfig access to cluster at /etc/rancher/rke2/rke2.yaml
- Infrastructure phase must complete before applications phase
- Longhorn must be deployed before applications (provides persistent storage)
- MetalLB must be deployed before applications (provides LoadBalancer IPs)
- cert-manager must be deployed before applications (provides TLS certificates)

## Example Playbook

```yaml
---
# Complete deployment workflow
- name: Prepare all nodes with prerequisites
  hosts: rke2_cluster
  become: yes
  roles:
    - common

- name: Deploy RKE2 HA cluster
  hosts: rke2_cluster
  become: yes
  roles:
    - role: lablabs.rke2

- name: Deploy infrastructure services
  hosts: rke2_servers[0]
  become: yes
  roles:
    - role: k8s_apps
      vars:
        deployment_phase: infrastructure

- name: Deploy application services
  hosts: rke2_servers[0]
  become: yes
  roles:
    - role: k8s_apps
      vars:
        deployment_phase: applications
```

Example inventory configuration:

```yaml
all:
  children:
    rke2_cluster:
      children:
        rke2_servers:
          hosts:
            opt1:
              ansible_host: 172.16.86.101
            opt2:
              ansible_host: 172.16.86.102
            opt3:
              ansible_host: 172.16.86.103
        rke2_agents:
          hosts:
            opt4:
              ansible_host: 172.16.86.104
            opt5:
              ansible_host: 172.16.86.105
  vars:
    ansible_user: ubuntu
    ansible_become: yes
    metallb_ip_range: "172.16.86.200-172.16.86.210"
    domain: "ljf.home"
    acme_email: "admin@ljf.home"
    minio_root_user: "admin"
    minio_root_pass: "{{ vault_minio_root_pass }}"
    n8n_admin_user: "admin"
    n8n_admin_pass: "{{ vault_n8n_admin_pass }}"
```

## Current Implementation

The role currently contains only placeholder tasks for development purposes. Full implementation will include:

**Infrastructure Phase:**

- Kubernetes API readiness check (300 second timeout)
- kube-proxy strictARP patch for MetalLB Layer 2 mode
- Longhorn deployment via Helm (10-minute wait timeout)
- MetalLB deployment via Helm (5-minute wait timeout)
- MetalLB IPAddressPool resource creation
- MetalLB L2Advertisement resource creation
- cert-manager deployment via Helm with CRDs
- Let's Encrypt staging ClusterIssuer with HTTP-01 solver

**Applications Phase:**

- MinIO deployment via Helm with Longhorn storage
- MinIO ingress at minio.{domain} with cert-manager TLS
- ClearML deployment via Helm with Longhorn storage
- ClearML webserver ingress at clearml.{domain}
- ClearML apiserver ingress at api.clearml.{domain}
- ClearML fileserver ingress at files.clearml.{domain}
- n8n deployment via Helm with Longhorn storage and basic auth
- n8n ingress at n8n.{domain} with cert-manager TLS

**Deployment Features:**

- Wait conditions for all Helm deployments
- MetalLB controller readiness check before IPAddressPool creation
- Error handling with diagnostic output
- Pod readiness verification before proceeding
- Namespace and ingress IP verification

## Testing

Currently no tests implemented. Will be added as part of task implementation.

**Planned Testing:**

- Pre-deployment connectivity tests
- Post-deployment cluster validation
- Service accessibility tests
- Idempotency verification
- Certificate validation
- Ingress IP assignment checks

## Usage Notes

**Secrets Management:**

Store sensitive credentials in an encrypted Ansible Vault file:

```bash
# Create vars/secrets.yml
cat > vars/secrets.yml << EOF
vault_minio_root_pass: "your-secure-password"
vault_n8n_admin_pass: "your-secure-password"
EOF

# Encrypt with Ansible Vault
ansible-vault encrypt vars/secrets.yml

# Run playbook with vault password
ansible-playbook playbook.yml --ask-vault-pass
```

**Service Access:**

After deployment, configure DNS or /etc/hosts to access services:

```
<ingress-ip> minio.ljf.home
<ingress-ip> clearml.ljf.home
<ingress-ip> api.clearml.ljf.home
<ingress-ip> files.clearml.ljf.home
<ingress-ip> n8n.ljf.home
```

Access services via HTTPS:

- MinIO: https://minio.ljf.home
- ClearML: https://clearml.ljf.home
- n8n: https://n8n.ljf.home

**Certificate Warnings:**

The role uses Let's Encrypt staging environment by default. Browsers will show certificate warnings (expected behavior). For production, update `certmanager_letsencrypt_server` to use the production URL.

## License

MIT-0

## Author Information

RKE2 Lab Automation Project

Part of the RKE2 MLOps Lab Automation system for deploying production-ready Kubernetes clusters with integrated storage, networking, and MLOps applications.
