# Quick Start Guide

Get your RKE2 cluster up and running in 30-45 minutes.

## Prerequisites

### Control Machine

- Python 3.12+
- Ansible 10.0.0+ (ansible-core 2.20.0+)
- SSH access to all target nodes
- Network connectivity to target nodes

### Target Nodes (5 nodes)

- **Operating System**: Ubuntu 24.04 LTS
- **Server Nodes (3)**: 8 GB RAM, 4 CPU cores, 100 GB disk
- **Agent Nodes (2)**: 8 GB RAM, 4 CPU cores, 100 GB disk
- **Network**: All nodes on same Layer 2 network segment
- **SSH**: Passwordless sudo configured for deployment user

### Network Requirements

- Static IP addresses for all 5 nodes
- Reserved IP range for MetalLB (outside DHCP scope)
- Firewall rules allowing:
  - SSH (22/tcp)
  - Kubernetes API (6443/tcp)
  - RKE2 registration (9345/tcp)
  - Kubelet metrics (10250/tcp)
  - etcd (2379-2380/tcp) between server nodes

## Installation Steps

### 1. Install Dependencies

```bash
# Install uv package manager (if not already installed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Python dependencies
uv sync

# Install Ansible dependencies
ansible-galaxy install -r requirements.yml
```

### 2. Configure Inventory

Edit `inventory.yml` with your node IP addresses and configuration:

```yaml
all:
  children:
    rke2_cluster:
      children:
        rke2_servers:
          hosts:
            node-1:
              ansible_host: 172.16.86.101  # Your server 1 IP
            node-2:
              ansible_host: 172.16.86.102  # Your server 2 IP
            node-3:
              ansible_host: 172.16.86.103  # Your server 3 IP
        rke2_agents:
          hosts:
            node-4:
              ansible_host: 172.16.86.104  # Your agent 1 IP
            node-5:
              ansible_host: 172.16.86.105  # Your agent 2 IP
  vars:
    ansible_user: ubuntu
    metallb_ip_range: "172.16.86.200-172.16.86.210"  # Your IP range
    domain: "ljf.home"  # Your domain
    acme_email: "admin@ljf.home"  # Your email
```

### 3. Configure Secrets

Create and encrypt sensitive credentials:

```bash
# Edit secrets file
cat > vars/secrets.yml << EOF
vault_minio_root_pass: "your-secure-minio-password"
vault_n8n_admin_pass: "your-secure-n8n-password"
EOF

# Encrypt with Ansible Vault
ansible-vault encrypt vars/secrets.yml
```

### 4. Test Connectivity

```bash
# Verify SSH access to all nodes
ansible all -m ping
```

### 5. Deploy the Stack

```bash
# Run the complete deployment
ansible-playbook playbook.yml --ask-vault-pass

# Or run in check mode first (dry run)
ansible-playbook playbook.yml --check --ask-vault-pass
```

## Deployment Phases

The automation executes in four sequential phases:

### Phase 1: Node Prerequisites (common role)

- Updates APT cache
- Installs required packages (open-iscsi, curl, vim, ca-certificates)
- Enables and starts iscsid service (required for Longhorn)
- Disables swap (required for Kubernetes)
- Verifies Ubuntu 24.04 LTS

**Target**: All 5 nodes  
**Duration**: ~2-3 minutes

### Phase 2: RKE2 Cluster (lablabs.rke2 role)

- Installs RKE2 on all nodes
- Configures 3-server HA cluster with etcd quorum
- Joins 2 agent nodes to the cluster
- Disables default rke2-service-lb (replaced by MetalLB)

**Target**: All 5 nodes  
**Duration**: ~5-10 minutes

### Phase 3: Infrastructure Services (k8s_apps role - infrastructure)

- **Longhorn**: Distributed block storage with replication
- **MetalLB**: Bare-metal load balancer with Layer 2 mode
- **cert-manager**: Automated TLS certificate management

**Target**: First server node (rke2_servers[0])  
**Duration**: ~10-15 minutes

### Phase 4: Application Services (k8s_apps role - applications)

- **MinIO**: S3-compatible object storage (50 GB)
- **ClearML**: MLOps platform with web UI, API, and file server (20 GB)
- **n8n**: Workflow automation platform (5 GB)

**Target**: First server node (rke2_servers[0])  
**Duration**: ~10-15 minutes

**Total Deployment Time**: ~30-45 minutes

## Next Steps

After deployment completes:

1. **Configure DNS** - See [Service Access Guide](SERVICE-ACCESS.md)
2. **Verify Deployment** - See [Verification Guide](VERIFICATION.md)
3. **Access Services** - See [Service Access Guide](SERVICE-ACCESS.md)
4. **Test Idempotency** - See [Testing Guide](TESTING.md)

## Troubleshooting

If deployment fails, see the [Troubleshooting Guide](TROUBLESHOOTING.md).

For detailed verification steps, see the [Verification Guide](VERIFICATION.md).
