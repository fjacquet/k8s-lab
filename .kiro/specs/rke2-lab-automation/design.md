# Design Document

## Overview

This design document describes the architecture and implementation approach for an Ansible-based automation system that provisions a production-ready MLOps and workflow automation platform on a 5-node RKE2 Kubernetes cluster running Ubuntu 24.04 LTS. The system deploys a complete stack including distributed storage (Longhorn), load balancing (MetalLB), certificate management (cert-manager), object storage (MinIO), MLOps platform (ClearML), and workflow automation (n8n).

The automation follows infrastructure-as-code principles, using declarative configuration to define the desired cluster state. The design prioritizes high availability with a 3-server control plane, idempotent deployments, and production-ready configurations. All services are accessible via HTTPS with automatic certificate management through Let's Encrypt.

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Control Machine                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Ansible Engine                                       │  │
│  │  - Playbook Orchestration                            │  │
│  │  - Inventory Management                              │  │
│  │  - Role Execution                                    │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ SSH
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Target Infrastructure (5 Nodes)           │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│  │ Node-1   │  │ Node-2   │  │ Node-3   │                 │
│  │ (Server) │  │ (Server) │  │ (Server) │                 │
│  │          │  │          │  │          │                 │
│  │ RKE2     │  │ RKE2     │  │ RKE2     │                 │
│  │ etcd     │  │ etcd     │  │ etcd     │                 │
│  │ API      │  │ API      │  │ API      │                 │
│  └──────────┘  └──────────┘  └──────────┘                 │
│                                                              │
│  ┌──────────┐  ┌──────────┐                                │
│  │ Node-4   │  │ Node-5   │                                │
│  │ (Agent)  │  │ (Agent)  │                                │
│  │          │  │          │                                │
│  │ RKE2     │  │ RKE2     │                                │
│  │ Kubelet  │  │ Kubelet  │                                │
│  └──────────┘  └──────────┘                                │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │         Infrastructure Services                    │    │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐          │    │
│  │  │ Longhorn │ │ MetalLB  │ │  Cert    │          │    │
│  │  │ Storage  │ │ LoadBal  │ │ Manager  │          │    │
│  │  └──────────┘ └──────────┘ └──────────┘          │    │
│  │                                                     │    │
│  │  ┌──────────┐                                      │    │
│  │  │  Ingress │                                      │    │
│  │  │  Nginx   │                                      │    │
│  │  └──────────┘                                      │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │         Application Services                       │    │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐          │    │
│  │  │  MinIO   │ │ ClearML  │ │   n8n    │          │    │
│  │  │  S3      │ │  MLOps   │ │ Workflow │          │    │
│  │  └──────────┘ └──────────┘ └──────────┘          │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  External Access: https://*.ljf.home (172.16.86.x)         │
└─────────────────────────────────────────────────────────────┘
```

### Component Architecture

#### Ansible Control Plane

- **Playbook**: Main orchestration file defining execution order
- **Inventory**: YAML file defining 5-node topology and variables
- **Roles**: Modular units of automation (common, k8s_apps)
- **Collections**: External dependencies (lablabs.rke2, kubernetes.core)
- **Templates**: Jinja2 templates for dynamic configuration

#### RKE2 Cluster (High Availability)

- **Server Nodes**: Three control plane nodes forming HA cluster with etcd quorum
- **Agent Nodes**: Two worker nodes running kubelet and container runtime
- **Networking**: Default CNI (Canal) for pod networking
- **Ingress**: Built-in nginx ingress controller for HTTP/HTTPS routing

#### Infrastructure Services

- **Longhorn**: Distributed block storage with replication across server nodes
- **MetalLB**: Bare-metal load balancer providing external IPs from 172.16.86.x range
- **Cert-Manager**: Automated TLS certificate provisioning via Let's Encrypt
- **Ingress-Nginx**: RKE2's built-in ingress for routing traffic to services

#### Application Services

- **MinIO**: S3-compatible object storage for ML artifacts and datasets
- **ClearML**: Complete MLOps platform with web UI, API server, and file server
- **n8n**: Workflow automation platform for orchestrating ML pipelines

## Components and Interfaces

### 1. Inventory Configuration

**File**: `inventory.yml`

**Purpose**: Defines cluster topology, node IP addresses, and configuration variables

**Structure**:

```yaml
all:
  children:
    rke2_cluster:
      children:
        rke2_servers:
          hosts:
            node-1:
              ansible_host: <server1_ip>
            node-2:
              ansible_host: <server2_ip>
            node-3:
              ansible_host: <server3_ip>
        rke2_agents:
          hosts:
            node-4:
              ansible_host: <agent1_ip>
            node-5:
              ansible_host: <agent2_ip>
  vars:
    ansible_user: ubuntu
    ansible_become: yes
    ansible_python_interpreter: /usr/bin/python3
    rke2_version: "v1.28.10+rke2r1"
    rke2_server_config:
      disable:
        - rke2-service-lb
      tls-san:
        - <server1_ip>
        - <server2_ip>
        - <server3_ip>
    metallb_ip_range: "172.16.86.200-172.16.86.210"
    domain: "ljf.home"
    acme_email: "admin@ljf.home"
    minio_root_user: "admin"
    minio_root_pass: "{{ vault_minio_root_pass }}"
    n8n_admin_user: "admin"
    n8n_admin_pass: "{{ vault_n8n_admin_pass }}"
```

**Key Variables**:

- `ansible_host`: IP address of each node (5 nodes total)
- `rke2_version`: Specific RKE2 version to install
- `rke2_server_config`: Configuration for HA setup with TLS SANs
- `metallb_ip_range`: IP range from 172.16.86.x network
- `domain`: Base domain for all services (ljf.home)
- `acme_email`: Email for Let's Encrypt certificate notifications
- `minio_root_user/pass`: MinIO admin credentials
- `n8n_admin_user/pass`: n8n admin credentials

### 2. Ansible Configuration

**File**: `ansible.cfg`

**Purpose**: Sets default Ansible behavior and connection parameters

**Configuration**:

```ini
[defaults]
inventory = inventory.yml
remote_user = ubuntu
private_key_file = ~/.ssh/id_rsa
host_key_checking = False
retry_files_enabled = False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 3600

[privilege_escalation]
become = True
become_method = sudo
become_user = root
```

### 3. Main Playbook

**File**: `playbook.yml`

**Purpose**: Orchestrates role execution in correct order

**Execution Flow**:

1. Execute `common` role on all nodes (prerequisites)
2. Execute `lablabs.rke2` role on all nodes (RKE2 HA cluster installation)
3. Execute `k8s_apps` role on first server node (infrastructure services)
4. Execute `k8s_apps` role on first server node (application services)

**Structure**:

```yaml
---
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

### 4. Common Role

**Directory**: `roles/common/`

**Purpose**: Prepares all nodes with required packages and system configuration

**Tasks** (`tasks/main.yml`):

```yaml
---
- name: Update APT cache
  apt:
    update_cache: yes
    cache_valid_time: 3600

- name: Install required packages
  apt:
    name:
      - open-iscsi
      - curl
      - vim
      - ca-certificates
    state: present

- name: Enable and start iscsid service
  systemd:
    name: iscsid
    enabled: yes
    state: started

- name: Disable swap immediately
  command: swapoff -a
  when: ansible_swaptotal_mb > 0

- name: Remove swap from fstab
  lineinfile:
    path: /etc/fstab
    regexp: '.*swap.*'
    state: absent

- name: Verify Ubuntu 24.04 LTS
  debug:
    msg: "Warning: Node is running {{ ansible_distribution }} {{ ansible_distribution_version }}, expected Ubuntu 24.04"
  when: ansible_distribution != "Ubuntu" or ansible_distribution_version != "24.04"
```

**Dependencies**: None

**Variables**: None (uses system facts)

### 5. lablabs.rke2 Role (External)

**Source**: Ansible Galaxy - `lablabs.rke2`

**Purpose**: Installs and configures RKE2 server and agent nodes

**Configuration Variables** (passed via inventory):

- `rke2_version`: RKE2 version to install
- `rke2_server_config`: Server-specific configuration
- `rke2_agent_config`: Agent-specific configuration (auto-generated)

**Key Features**:

- Idempotent installation
- Automatic token management
- Service lifecycle management
- Configuration templating
- Kubeconfig retrieval

**Interface**: Role consumes inventory variables and manages RKE2 installation lifecycle

### 6. K8s Apps Role

**Directory**: `roles/k8s_apps/`

**Purpose**: Deploys infrastructure and application services using Helm in two phases

**Phase 1 - Infrastructure Services**:

- Longhorn (distributed storage)
- MetalLB (load balancer)
- Cert-Manager (certificate management)

**Phase 2 - Application Services**:

- MinIO (S3 object storage)
- ClearML (MLOps platform)
- n8n (workflow automation)

**Tasks** (`tasks/main.yml`):

```yaml
---
- name: Wait for Kubernetes API to be ready
  wait_for:
    host: "{{ ansible_host }}"
    port: 6443
    timeout: 300

- name: Set kubeconfig environment variable
  set_fact:
    kubeconfig_path: /etc/rancher/rke2/rke2.yaml

# ===== INFRASTRUCTURE PHASE =====
- name: Infrastructure services deployment
  when: deployment_phase == 'infrastructure'
  block:
    - name: Patch kube-proxy for strictARP (required by MetalLB)
      kubernetes.core.k8s_json_patch:
        kubeconfig: "{{ kubeconfig_path }}"
        kind: ConfigMap
        namespace: kube-system
        name: kube-proxy
        patch:
          - op: replace
            path: /data/config.conf
            value: |
              apiVersion: kubeproxy.config.k8s.io/v1alpha1
              kind: KubeProxyConfiguration
              mode: "ipvs"
              ipvs:
                strictARP: true

    - name: Add Longhorn Helm repository
      kubernetes.core.helm_repository:
        name: longhorn
        repo_url: https://charts.longhorn.io
        state: present

    - name: Install Longhorn (distributed storage)
      kubernetes.core.helm:
        name: longhorn
        chart_ref: longhorn/longhorn
        release_namespace: longhorn-system
        create_namespace: yes
        kubeconfig: "{{ kubeconfig_path }}"
        state: present
        wait: yes
        wait_timeout: 10m

    - name: Add MetalLB Helm repository
      kubernetes.core.helm_repository:
        name: metallb
        repo_url: https://metallb.github.io/metallb
        state: present

    - name: Install MetalLB (load balancer)
      kubernetes.core.helm:
        name: metallb
        chart_ref: metallb/metallb
        release_namespace: metallb-system
        create_namespace: yes
        kubeconfig: "{{ kubeconfig_path }}"
        state: present
        wait: yes
        wait_timeout: 5m

    - name: Wait for MetalLB controller to be ready
      kubernetes.core.k8s_info:
        kind: Deployment
        namespace: metallb-system
        name: metallb-controller
        kubeconfig: "{{ kubeconfig_path }}"
        wait: yes
        wait_condition:
          type: Available
          status: "True"
        wait_timeout: 300

    - name: Create MetalLB IPAddressPool
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig_path }}"
        state: present
        definition:
          apiVersion: metallb.io/v1beta1
          kind: IPAddressPool
          metadata:
            name: default-pool
            namespace: metallb-system
          spec:
            addresses:
              - "{{ metallb_ip_range }}"

    - name: Create MetalLB L2Advertisement
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig_path }}"
        state: present
        definition:
          apiVersion: metallb.io/v1beta1
          kind: L2Advertisement
          metadata:
            name: default-l2
            namespace: metallb-system
          spec:
            ipAddressPools:
              - default-pool

    - name: Add Cert-Manager Helm repository
      kubernetes.core.helm_repository:
        name: jetstack
        repo_url: https://charts.jetstack.io
        state: present

    - name: Install Cert-Manager (certificate management)
      kubernetes.core.helm:
        name: cert-manager
        chart_ref: jetstack/cert-manager
        release_namespace: cert-manager
        create_namespace: yes
        kubeconfig: "{{ kubeconfig_path }}"
        state: present
        wait: yes
        wait_timeout: 5m
        values:
          installCRDs: true

    - name: Create Let's Encrypt Staging ClusterIssuer
      kubernetes.core.k8s:
        kubeconfig: "{{ kubeconfig_path }}"
        state: present
        definition:
          apiVersion: cert-manager.io/v1
          kind: ClusterIssuer
          metadata:
            name: letsencrypt-staging
          spec:
            acme:
              server: https://acme-staging-v02.api.letsencrypt.org/directory
              email: "{{ acme_email }}"
              privateKeySecretRef:
                name: letsencrypt-staging
              solvers:
                - http01:
                    ingress:
                      class: nginx

# ===== APPLICATION PHASE =====
- name: Application services deployment
  when: deployment_phase == 'applications'
  block:
    - name: Add MinIO Helm repository
      kubernetes.core.helm_repository:
        name: minio
        repo_url: https://charts.min.io/
        state: present

    - name: Install MinIO (S3 object storage)
      kubernetes.core.helm:
        name: minio
        chart_ref: minio/minio
        release_namespace: minio
        create_namespace: yes
        kubeconfig: "{{ kubeconfig_path }}"
        state: present
        wait: yes
        wait_timeout: 5m
        values:
          persistence:
            storageClass: "longhorn"
          rootUser: "{{ minio_root_user }}"
          rootPassword: "{{ minio_root_pass }}"
          service:
            type: ClusterIP
          ingress:
            enabled: true
            ingressClassName: "nginx"
            hosts:
              - "minio.{{ domain }}"
            annotations:
              cert-manager.io/cluster-issuer: "letsencrypt-staging"

    - name: Add ClearML Helm repository
      kubernetes.core.helm_repository:
        name: clearml
        repo_url: https://allegroai.github.io/clearml-helm-charts
        state: present

    - name: Install ClearML (MLOps platform)
      kubernetes.core.helm:
        name: clearml
        chart_ref: clearml/clearml
        release_namespace: clearml
        create_namespace: yes
        kubeconfig: "{{ kubeconfig_path }}"
        state: present
        wait: yes
        wait_timeout: 10m
        values:
          persistence:
            storageClass: "longhorn"
          webserver:
            service:
              type: ClusterIP
            ingress:
              enabled: true
              ingressClassName: "nginx"
              host: "clearml.{{ domain }}"
              annotations:
                cert-manager.io/cluster-issuer: "letsencrypt-staging"
          apiserver:
            service:
              type: ClusterIP
            ingress:
              enabled: true
              ingressClassName: "nginx"
              host: "api.clearml.{{ domain }}"
              annotations:
                cert-manager.io/cluster-issuer: "letsencrypt-staging"
          fileserver:
            service:
              type: ClusterIP
            ingress:
              enabled: true
              ingressClassName: "nginx"
              host: "files.clearml.{{ domain }}"
              annotations:
                cert-manager.io/cluster-issuer: "letsencrypt-staging"

    - name: Add n8n Helm repository
      kubernetes.core.helm_repository:
        name: n8n
        repo_url: https://helm.n8n.io
        state: present

    - name: Install n8n (workflow automation)
      kubernetes.core.helm:
        name: n8n
        chart_ref: n8n/n8n
        release_namespace: n8n
        create_namespace: yes
        kubeconfig: "{{ kubeconfig_path }}"
        state: present
        wait: yes
        wait_timeout: 5m
        values:
          basicAuth:
            enabled: true
            user: "{{ n8n_admin_user }}"
            password: "{{ n8n_admin_pass }}"
          persistence:
            enabled: true
            storageClass: "longhorn"
          service:
            type: ClusterIP
          ingress:
            enabled: true
            ingressClassName: "nginx"
            hosts:
              - "n8n.{{ domain }}"
            annotations:
              cert-manager.io/cluster-issuer: "letsencrypt-staging"
```

**Dependencies**:

- kubernetes.core collection
- RKE2 HA cluster must be running
- Kubeconfig must be accessible
- Longhorn must be deployed before applications (for persistent storage)
- MetalLB and Cert-Manager must be deployed before applications (for ingress)

**Variables**:

- `deployment_phase`: Either 'infrastructure' or 'applications'
- `metallb_ip_range`: IP range for load balancer (from inventory)
- `domain`: Base domain for all services (ljf.home)
- `acme_email`: Email for Let's Encrypt notifications
- `minio_root_user/pass`: MinIO admin credentials
- `n8n_admin_user/pass`: n8n admin credentials
- `kubeconfig_path`: Path to kubeconfig file

### 7. Secrets File

**File**: `vars/secrets.yml` (encrypted with Ansible Vault)

**Purpose**: Stores sensitive credentials encrypted with Ansible Vault

**Content** (before encryption):

```yaml
---
vault_minio_root_pass: "your-secure-minio-password"
vault_n8n_admin_pass: "your-secure-n8n-password"
```

**Encryption**:

```bash
# Encrypt the file
ansible-vault encrypt vars/secrets.yml

# Edit encrypted file
ansible-vault edit vars/secrets.yml

# View encrypted file
ansible-vault view vars/secrets.yml
```

**Usage**: Reference variables in inventory as `{{ vault_minio_root_pass }}`

**Playbook Execution**: `ansible-playbook playbook.yml --ask-vault-pass`

### 8. Requirements File

**File**: `requirements.yml`

**Purpose**: Declares external Ansible dependencies

**Content**:

```yaml
---
roles:
  - name: lablabs.rke2
    version: "2.0.0"

collections:
  - name: kubernetes.core
    version: "3.0.0"
```

**Installation**: `ansible-galaxy install -r requirements.yml`

## Data Models

### Inventory Data Model

```yaml
Node:
  hostname: string
  ansible_host: string (IP address)
  role: enum [server, agent]

Cluster:
  nodes: list[Node]  # 5 nodes: 3 servers + 2 agents
  rke2_version: string
  server_config: dict
  metallb_ip_range: string
  domain: string
  acme_email: string
  service_credentials: dict
```

### RKE2 Configuration Model

```yaml
ServerConfig:
  disable: list[string]  # Services to disable (e.g., rke2-service-lb)
  tls-san: list[string]  # TLS SANs for all server IPs (required for HA)
  token: string          # Shared cluster token (auto-generated)

AgentConfig:
  server: string         # Server URL (auto-generated)
  token: string          # Join token (auto-generated)
```

### MetalLB Configuration Model

```yaml
IPAddressPool:
  apiVersion: metallb.io/v1beta1
  kind: IPAddressPool
  metadata:
    name: string
    namespace: string
  spec:
    addresses: list[string]  # CIDR or range notation (172.16.86.x)

L2Advertisement:
  apiVersion: metallb.io/v1beta1
  kind: L2Advertisement
  metadata:
    name: string
    namespace: string
  spec:
    ipAddressPools: list[string]
```

### Cert-Manager Configuration Model

```yaml
ClusterIssuer:
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: string
  spec:
    acme:
      server: string  # Let's Encrypt staging/production URL
      email: string
      privateKeySecretRef:
        name: string
      solvers:
        - http01:
            ingress:
              class: string  # nginx
```

### Application Ingress Model

```yaml
Ingress:
  enabled: true
  ingressClassName: "nginx"
  hosts: list[string]  # e.g., ["minio.ljf.home"]
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
```

## Error Handling

### Connection Errors

**Strategy**: Fail fast on SSH connection errors

**Implementation**:

- Ansible's built-in connection retry mechanism
- `host_key_checking = False` to avoid known_hosts issues
- Clear error messages showing which node failed

**Example**:

```yaml
- name: Test connectivity
  ping:
  register: ping_result
  failed_when: ping_result is failed
```

### Service Startup Failures

**Strategy**: Use systemd status checks and wait conditions

**Implementation**:

```yaml
- name: Start RKE2 server
  systemd:
    name: rke2-server
    state: started
    enabled: yes
  register: service_result
  failed_when: service_result is failed

- name: Wait for API server
  wait_for:
    host: "{{ ansible_host }}"
    port: 6443
    timeout: 300
  register: wait_result
  failed_when: wait_result is failed
```

### Helm Deployment Failures

**Strategy**: Use wait conditions and timeout handling

**Implementation**:

```yaml
- name: Install Longhorn
  kubernetes.core.helm:
    name: longhorn
    chart_ref: longhorn/longhorn
    release_namespace: longhorn-system
    wait: yes
    wait_timeout: 600s
  register: helm_result
  failed_when: helm_result is failed
```

**Error Output**: Helm module provides detailed failure reasons including pod status

### Version Validation

**Strategy**: Warn but continue on version mismatch

**Implementation**:

```yaml
- name: Check Ubuntu version
  debug:
    msg: "Warning: Expected Ubuntu 24.04, found {{ ansible_distribution_version }}"
  when: ansible_distribution_version != "24.04"
```

## Testing Strategy

### Pre-Deployment Validation

**Connectivity Test**:

```bash
ansible all -m ping
```

**Syntax Check**:

```bash
ansible-playbook playbook.yml --syntax-check
```

**Dry Run**:

```bash
ansible-playbook playbook.yml --check
```

### Post-Deployment Validation

**Cluster Status**:

```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get nodes
kubectl get pods -A
```

**Infrastructure Services Validation**:

```bash
# Longhorn
kubectl get pods -n longhorn-system
kubectl get storageclass

# MetalLB
kubectl get pods -n metallb-system
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system

# Cert-Manager
kubectl get pods -n cert-manager
kubectl get clusterissuer
```

**Application Services Validation**:

```bash
# MinIO
kubectl get pods -n minio
kubectl get ingress -n minio

# ClearML
kubectl get pods -n clearml
kubectl get ingress -n clearml

# n8n
kubectl get pods -n n8n
kubectl get ingress -n n8n
```

**Ingress and Certificate Validation**:

```bash
# Check all ingress resources
kubectl get ingress -A

# Check certificate requests
kubectl get certificate -A
kubectl get certificaterequest -A

# Verify ingress has assigned IPs
kubectl get ingress -A -o wide
```

**Service Access Test**:

```bash
# Test HTTPS access to services (requires DNS or /etc/hosts configuration)
curl -k https://minio.ljf.home
curl -k https://clearml.ljf.home
curl -k https://n8n.ljf.home
```

### Idempotency Testing

**Strategy**: Run playbook multiple times and verify no changes

**Test**:

```bash
# First run
ansible-playbook playbook.yml

# Second run - should show no changes
ansible-playbook playbook.yml
```

**Expected Result**: Second run shows `changed=0` for all tasks

### Rollback Strategy

**Manual Rollback**:

1. Uninstall application Helm releases:
   - `helm uninstall n8n -n n8n`
   - `helm uninstall clearml -n clearml`
   - `helm uninstall minio -n minio`
2. Uninstall infrastructure Helm releases:
   - `helm uninstall cert-manager -n cert-manager`
   - `helm uninstall metallb -n metallb-system`
   - `helm uninstall longhorn -n longhorn-system`
3. Stop RKE2 services on all nodes:
   - `systemctl stop rke2-server` (on server nodes)
   - `systemctl stop rke2-agent` (on agent nodes)
4. Remove RKE2 data: `rm -rf /var/lib/rancher/rke2`
5. Re-run playbook for clean deployment

**Automated Rollback**: Not implemented (future enhancement)

## Security Considerations

### SSH Key Authentication

- Use SSH keys instead of passwords
- Configure `ansible_ssh_private_key_file` in inventory
- Disable password authentication on target nodes

### Privilege Escalation

- Use `become: yes` for privilege escalation
- Configure passwordless sudo for ansible user
- Limit sudo access to required commands only

### Secrets Management

- RKE2 token auto-generated and stored securely
- Kubeconfig file permissions set to 600
- **Ansible Vault** for encrypting sensitive credentials:
  - Store secrets in `vars/secrets.yml` (encrypted file)
  - Encrypt with: `ansible-vault encrypt vars/secrets.yml`
  - Run playbook with: `ansible-playbook playbook.yml --ask-vault-pass`
  - Safe to commit encrypted file to Git
- Let's Encrypt private keys managed by cert-manager
- No hardcoded credentials in playbooks or inventory files

### Network Security

- Configure firewall rules for required ports only
- Use private network for cluster communication
- Restrict API server access to authorized IPs

### Updates and Patching

- Enable unattended-upgrades for security patches
- Pin RKE2 version to avoid unexpected upgrades
- Test updates in staging before production

## Performance Considerations

### Parallel Execution

- Ansible executes tasks in parallel across nodes by default
- Use `serial` parameter to control parallelism if needed
- Agent nodes can be provisioned simultaneously

### Fact Caching

- Enable fact caching to reduce gather time on subsequent runs
- Cache facts to `/tmp/ansible_facts` with 1-hour timeout

### Resource Requirements

**Control Machine**:

- Minimal requirements (any modern laptop)
- Network connectivity to target nodes
- Ansible 3.4.0+ installed

**Server Nodes (3 nodes)**:

- 8 GB RAM minimum (16 GB recommended for production workloads)
- 4 CPU cores minimum
- 100 GB disk space (for etcd, control plane, and Longhorn storage)
- Gigabit network interface

**Agent Nodes (2 nodes)**:

- 8 GB RAM minimum (16 GB recommended for ML workloads)
- 4 CPU cores minimum
- 100 GB disk space (for container images and Longhorn storage)
- Gigabit network interface

**Total Cluster Resources**:

- 40 GB RAM minimum (80 GB recommended)
- 20 CPU cores minimum
- 500 GB total disk space
- All nodes on same network segment for MetalLB Layer 2

## Network and DNS Configuration

### DNS Requirements

**Option 1: Local DNS Server**

Configure a local DNS server to resolve `*.ljf.home` to the ingress IP address:

```
*.ljf.home A <ingress-ip>
```

**Option 2: /etc/hosts Configuration**

Add entries to `/etc/hosts` on client machines:

```
<ingress-ip> minio.ljf.home
<ingress-ip> clearml.ljf.home
<ingress-ip> api.clearml.ljf.home
<ingress-ip> files.clearml.ljf.home
<ingress-ip> n8n.ljf.home
```

### Network Requirements

- All 5 nodes must be on the same Layer 2 network segment
- MetalLB IP range (172.16.86.x) must be in the same subnet as nodes
- IP range must be outside DHCP scope to avoid conflicts
- Firewall rules must allow:
  - SSH (22/tcp) for Ansible
  - RKE2 API (6443/tcp)
  - RKE2 registration (9345/tcp)
  - Kubelet metrics (10250/tcp)
  - etcd (2379-2380/tcp) between server nodes
  - HTTP/HTTPS (80/443) to ingress IP

### Certificate Considerations

- Let's Encrypt staging certificates are not trusted by browsers
- Users will see certificate warnings (expected for staging)
- For production use, switch to Let's Encrypt production issuer
- HTTP-01 challenge requires port 80 accessible from internet (or use DNS-01)

## Deployment Workflow

### Initial Deployment

1. **Prepare Control Machine**:

   ```bash
   # Install Ansible
   pip install ansible
   
   # Install dependencies
   ansible-galaxy install -r requirements.yml
   ```

2. **Configure Inventory**:
   - Edit `inventory.yml` with 5 node IP addresses (3 servers + 2 agents)
   - Set MetalLB IP range (172.16.86.x)
   - Configure domain (ljf.home)
   - Set ACME email for Let's Encrypt
   - Configure service credentials (use Ansible Vault)
   - Configure SSH key path

3. **Create and Encrypt Secrets File**:

   ```bash
   # Create vars/secrets.yml with sensitive credentials
   cat > vars/secrets.yml << EOF
   vault_minio_root_pass: "your-secure-password"
   vault_n8n_admin_pass: "your-secure-password"
   EOF
   
   # Encrypt the file with Ansible Vault
   ansible-vault encrypt vars/secrets.yml
   
   # File is now encrypted and safe to commit to Git
   ```

4. **Test Connectivity**:

   ```bash
   ansible all -m ping
   ```

5. **Run Playbook**:

   ```bash
   ansible-playbook playbook.yml --ask-vault-pass
   ```

6. **Verify Deployment**:

   ```bash
   export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
   kubectl get nodes  # Should show 5 nodes (3 servers, 2 agents)
   kubectl get pods -A
   kubectl get ingress -A
   ```

7. **Configure DNS or /etc/hosts**:

   ```bash
   # Add entries for service access
   <ingress-ip> minio.ljf.home
   <ingress-ip> clearml.ljf.home
   <ingress-ip> api.clearml.ljf.home
   <ingress-ip> files.clearml.ljf.home
   <ingress-ip> n8n.ljf.home
   ```

8. **Access Services**:
   - MinIO: https://minio.ljf.home
   - ClearML: https://clearml.ljf.home
   - n8n: https://n8n.ljf.home

### Update Workflow

1. **Modify Configuration**: Update inventory or role variables
2. **Dry Run**: `ansible-playbook playbook.yml --check`
3. **Apply Changes**: `ansible-playbook playbook.yml`
4. **Verify**: Check cluster status

### Maintenance Operations

**Add Node**: Add to inventory and run playbook (maintains HA with odd number of servers)
**Remove Node**: Remove from inventory, drain node manually, run playbook
**Upgrade RKE2**: Update `rke2_version` and run playbook (servers upgrade first, then agents)
**Update Applications**: Modify Helm values in k8s_apps role and run specific phase
**Rotate Certificates**: Cert-manager handles automatic renewal (30 days before expiry)
**Update Service Credentials**: Update vault, run playbook with `--ask-vault-pass`

## Design Decisions and Rationale

### Use Community Roles vs Custom Scripts

**Decision**: Use `lablabs.rke2` role instead of custom shell scripts

**Rationale**:

- Idempotent by design
- Battle-tested by community
- Handles edge cases and upgrades
- Reduces maintenance burden
- Follows Ansible best practices

### High Availability Control Plane

**Decision**: Deploy three server nodes for HA control plane

**Rationale**:

- Production-ready configuration with fault tolerance
- Maintains quorum with 2 of 3 servers operational
- Automatic failover for API server and etcd
- Supports MLOps workloads requiring high availability
- Minimal additional resource overhead (3 servers vs 1)

### Phased Deployment (Infrastructure then Applications)

**Decision**: Deploy infrastructure services before application services

**Rationale**:

- Longhorn must be available before applications request persistent storage
- MetalLB must be configured before ingress resources need external IPs
- Cert-manager must be ready before certificates are requested
- Clear separation of concerns for troubleshooting
- Allows infrastructure validation before application deployment

### Use RKE2 Built-in Ingress Controller

**Decision**: Use RKE2's built-in nginx ingress instead of deploying separate ingress

**Rationale**:

- Pre-installed and configured with RKE2
- One less component to manage
- Consistent with RKE2 best practices
- Reduces deployment complexity
- Well-integrated with RKE2 networking

### Let's Encrypt Staging for Initial Deployment

**Decision**: Use Let's Encrypt staging environment initially

**Rationale**:

- Avoid rate limits during testing and development
- Staging certificates allow full TLS testing
- Easy to switch to production issuer after validation
- Prevents accidental rate limit exhaustion
- Staging API has higher rate limits

### Ingress-Based Service Access (Not LoadBalancer)

**Decision**: Use Ingress resources with cert-manager instead of LoadBalancer services

**Rationale**:

- Single external IP for all services (efficient IP usage)
- Automatic TLS certificate management
- Host-based routing (clearml.ljf.home, minio.ljf.home, etc.)
- Standard production pattern
- Better integration with certificate management

### MetalLB Layer 2 Mode

**Decision**: Use Layer 2 mode instead of BGP

**Rationale**:

- No router configuration required
- Simpler setup for lab environment
- Works on any network
- Sufficient for small deployments
- No special hardware needed

### Disable RKE2 Service LoadBalancer

**Decision**: Disable built-in service-lb in favor of MetalLB

**Rationale**:

- MetalLB provides more features
- Industry-standard solution
- Better integration with monitoring
- More flexible IP management
- Consistent with production practices

### Ubuntu 24.04 LTS

**Decision**: Target Ubuntu 24.04 LTS specifically

**Rationale**:

- Long-term support until 2029
- Modern kernel (6.8+)
- Latest package versions
- Python 3.12 default
- Security updates guaranteed

### MinIO for Object Storage

**Decision**: Deploy MinIO instead of using external S3 or other object storage

**Rationale**:

- S3-compatible API (works with existing ML tools)
- Self-hosted (no cloud dependencies or costs)
- High performance for ML artifact storage
- Integrates well with ClearML for model and dataset storage
- Simple deployment via Helm chart

### ClearML for MLOps Platform

**Decision**: Deploy ClearML as the primary MLOps platform

**Rationale**:

- Complete MLOps solution (experiment tracking, model registry, pipelines)
- Open-source with active community
- Integrates with popular ML frameworks (PyTorch, TensorFlow, etc.)
- Web-based UI for easy access
- Supports distributed training and hyperparameter optimization
- Works well with MinIO for artifact storage

### n8n for Workflow Automation

**Decision**: Deploy n8n as workflow automation platform

**Rationale**:

- Open-source alternative to Zapier/Make
- Visual workflow builder (low-code)
- Can orchestrate ML pipelines and integrate services
- Connects ClearML, MinIO, and external services
- Self-hosted (no data leaves the cluster)
- Extensible with custom nodes

### Ansible Vault for Secrets Management

**Decision**: Use Ansible Vault (built-in Ansible feature) for encrypting sensitive credentials

**Rationale**:

- Built into Ansible (no additional software required)
- Encrypts entire file (vars/secrets.yml) with AES256
- Safe to commit encrypted files to Git
- Simple workflow: encrypt once, use with `--ask-vault-pass`
- No external secret management service needed
- Supports multiple vault passwords for different environments
- Can be integrated with CI/CD pipelines
