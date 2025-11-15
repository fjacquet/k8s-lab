# Configuration Guide

This guide explains all configuration options for the RKE2 Lab Automation project.

## Inventory Configuration

The `inventory.yml` file defines your cluster topology and configuration.

### Complete Inventory Template

```yaml
all:
  children:
    rke2_cluster:
      children:
        # Server nodes (control plane + etcd)
        rke2_servers:
          hosts:
            opt1:
              ansible_host: 172.16.86.101 # Server 1 IP
            opt2:
              ansible_host: 172.16.86.102 # Server 2 IP
            opt3:
              ansible_host: 172.16.86.103 # Server 3 IP

        # Agent nodes (workers)
        rke2_agents:
          hosts:
            opt4:
              ansible_host: 172.16.86.104 # Agent 1 IP
            opt5:
              ansible_host: 172.16.86.105 # Agent 2 IP

  vars:
    # Ansible connection settings
    ansible_user: ubuntu # SSH user (must have passwordless sudo)
    ansible_become: yes # Use sudo for privilege escalation
    ansible_python_interpreter: /usr/bin/python3 # Python 3 interpreter path

    # RKE2 configuration
    rke2_version: "v1.28.10+rke2r1" # RKE2 version to install
    rke2_server_config:
      disable:
        - rke2-service-lb # Disable default service-lb (using MetalLB)
      tls-san: # TLS SANs for API server certificate
        - 172.16.86.101 # Server 1 IP
        - 172.16.86.102 # Server 2 IP
        - 172.16.86.103 # Server 3 IP
        - cluster.ljf.home # Optional: cluster domain name

    # MetalLB configuration
    metallb_ip_range: "172.16.86.200-172.16.86.210" # IP range for LoadBalancer services

    # Domain and certificate configuration
    domain: "ljf.home" # Base domain for all services
    acme_email: "admin@ljf.home" # Email for Let's Encrypt notifications

    # MinIO credentials
    minio_root_user: "admin" # MinIO admin username
    minio_root_pass: "{{ vault_minio_root_pass }}" # From vars/secrets.yml (encrypted)

    # n8n credentials
    n8n_admin_user: "admin" # n8n admin username
    n8n_admin_pass: "{{ vault_n8n_admin_pass }}" # From vars/secrets.yml (encrypted)
```

## Required Variables

| Variable                | Required | Description                          | Example                       |
| ----------------------- | -------- | ------------------------------------ | ----------------------------- |
| `ansible_host`          | ✅ Yes   | IP address of each node              | `172.16.86.101`               |
| `ansible_user`          | ✅ Yes   | SSH user with sudo access            | `ubuntu`                      |
| `rke2_version`          | ✅ Yes   | RKE2 version to install              | `v1.28.10+rke2r1`             |
| `metallb_ip_range`      | ✅ Yes   | IP range for MetalLB (CIDR or range) | `172.16.86.200-172.16.86.210` |
| `domain`                | ✅ Yes   | Base domain for services             | `ljf.home`                    |
| `acme_email`            | ✅ Yes   | Email for Let's Encrypt              | `admin@ljf.home`              |
| `vault_minio_root_pass` | ✅ Yes   | MinIO password (in secrets.yml)      | `secure-password`             |
| `vault_n8n_admin_pass`  | ✅ Yes   | n8n password (in secrets.yml)        | `secure-password`             |

## Optional Variables

| Variable                     | Default            | Description                        |
| ---------------------------- | ------------------ | ---------------------------------- |
| `ansible_become`             | `yes`              | Use sudo for privilege escalation  |
| `ansible_python_interpreter` | `/usr/bin/python3` | Python interpreter path            |
| `minio_root_user`            | `admin`            | MinIO admin username               |
| `n8n_admin_user`             | `admin`            | n8n admin username                 |
| `rke2_server_config.tls-san` | Node IPs           | Additional TLS SANs for API server |

## Network Configuration

### MetalLB IP Range

**Requirements**:

- Must be in the same subnet as your nodes
- Must be outside DHCP scope to avoid conflicts
- Recommended: Reserve 10-20 IPs for services
- Format: Range (`172.16.86.200-172.16.86.210`) or CIDR (`172.16.86.200/29`)

**Example Network Layout**:

```
Network: 172.16.86.0/24
Gateway: 172.16.86.1
DHCP Range: 172.16.86.50-172.16.86.150
Node IPs: 172.16.86.101-172.16.86.105 (static)
MetalLB Range: 172.16.86.200-172.16.86.210 (static, reserved)
```

## RKE2 Version Selection

### Stable Releases

Use stable RKE2 versions from [RKE2 Releases](https://github.com/rancher/rke2/releases)

**Version Format**: `v1.28.10+rke2r1`

- `v1.28.10`: Kubernetes version
- `+rke2r1`: RKE2 release number

**Recommended Versions**:

- Production: Latest stable release (e.g., `v1.28.10+rke2r1`)
- Testing: Latest release candidate (e.g., `v1.29.0-rc1+rke2r1`)

## Service Versions

Service versions are defined in `roles/k8s_apps/defaults/main.yml`:

| Service      | Default Version | Namespace       | Chart Repository                                |
| ------------ | --------------- | --------------- | ----------------------------------------------- |
| Longhorn     | 1.6.0           | longhorn-system | https://charts.longhorn.io                      |
| MetalLB      | 0.14.3          | metallb-system  | https://metallb.github.io/metallb               |
| cert-manager | v1.14.2         | cert-manager    | https://charts.jetstack.io                      |
| MinIO        | 5.0.15          | minio           | https://charts.min.io/                          |
| ClearML      | 7.4.0           | clearml         | https://allegroai.github.io/clearml-helm-charts |
| n8n          | 0.234.0         | n8n             | https://helm.n8n.io                             |

To update versions, edit `roles/k8s_apps/defaults/main.yml` and re-run the playbook.

## Ansible Vault Setup

Ansible Vault encrypts sensitive credentials using AES256 encryption.

### Initial Setup

1. **Create the secrets file**:

```bash
cat > vars/secrets.yml << EOF
---
vault_minio_root_pass: "your-secure-minio-password"
vault_n8n_admin_pass: "your-secure-n8n-password"
EOF
```

2. **Encrypt the file**:

```bash
ansible-vault encrypt vars/secrets.yml
# You'll be prompted to create a vault password
# Store this password securely - you'll need it for every deployment
```

3. **Verify encryption**:

```bash
cat vars/secrets.yml
# Should show encrypted content starting with $ANSIBLE_VAULT;1.1;AES256
```

### Managing Encrypted Secrets

```bash
# View encrypted file contents
ansible-vault view vars/secrets.yml

# Edit encrypted file (decrypts, opens editor, re-encrypts on save)
ansible-vault edit vars/secrets.yml

# Change vault password
ansible-vault rekey vars/secrets.yml

# Decrypt file (not recommended - keep encrypted)
ansible-vault decrypt vars/secrets.yml

# Re-encrypt a decrypted file
ansible-vault encrypt vars/secrets.yml
```

### Running Playbook with Vault

**Option 1: Interactive password prompt (recommended for manual runs)**

```bash
ansible-playbook playbook.yml --ask-vault-pass
```

**Option 2: Password file (for automation)**

```bash
# Create password file (keep secure, add to .gitignore)
echo "your-vault-password" > ~/.vault_pass
chmod 600 ~/.vault_pass

# Use password file
ansible-playbook playbook.yml --vault-password-file ~/.vault_pass
```

**Option 3: Environment variable**

```bash
# Set environment variable
export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault_pass

# Run playbook (will use password file automatically)
ansible-playbook playbook.yml
```

### Best Practices

- ✅ **DO** commit encrypted `vars/secrets.yml` to Git
- ✅ **DO** store vault password in a password manager
- ✅ **DO** use different vault passwords for different environments
- ✅ **DO** add `.vault_pass` to `.gitignore` if using password files
- ❌ **DON'T** commit unencrypted secrets
- ❌ **DON'T** commit vault password files
- ❌ **DON'T** share vault passwords via insecure channels

## Customization Examples

### Custom SSH Key

```yaml
vars:
  ansible_ssh_private_key_file: ~/.ssh/custom_key
```

### Custom SSH Port

```yaml
hosts:
  opt1:
    ansible_host: 172.16.86.101
    ansible_port: 2222
```

### Custom Domain per Service

```yaml
vars:
  minio_domain: "storage.example.com"
  clearml_domain: "mlops.example.com"
  n8n_domain: "workflows.example.com"
```

### Disable Specific Services

Edit `roles/k8s_apps/tasks/main.yml` and comment out unwanted services.

## Advanced Configuration

### RKE2 Server Configuration

Additional RKE2 server options can be added to `rke2_server_config`:

```yaml
rke2_server_config:
  disable:
    - rke2-service-lb
  tls-san:
    - 172.16.86.101
    - 172.16.86.102
    - 172.16.86.103
  cluster-cidr: "10.42.0.0/16"
  service-cidr: "10.43.0.0/16"
  cluster-dns: "10.43.0.10"
```

### Custom Helm Values

To customize Helm chart values, edit `roles/k8s_apps/tasks/main.yml` and add values to the `values` parameter:

```yaml
- name: Deploy MinIO
  kubernetes.core.helm:
    name: minio
    chart_ref: minio/minio
    release_namespace: minio
    create_namespace: yes
    values:
      replicas: 4 # Custom value
      resources:
        requests:
          memory: "4Gi"
```

## Next Steps

- Deploy the cluster: [Quick Start Guide](QUICKSTART.md)
- Verify deployment: [Verification Guide](VERIFICATION.md)
- Configure service access: [Service Access Guide](SERVICE-ACCESS.md)
