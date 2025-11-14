# The Self-Hosted MLOps & Automation Lab

## Project Goal

Build a complete, private, and powerful platform for machine learning (ML) development and workflow automation using five physical servers.

Instead of relying on expensive cloud services (AWS, GCP, Zapier), we're building a private "cloud" from the ground up. The entire system will be built and configured automatically using Ansible, allowing you to rebuild or update the entire lab with a single command.

## Architecture Overview

### Foundation Layer: Ansible

Automated construction crew that builds everything from blueprints (Ansible playbooks). Execute once, deploy perfectly every time.

### Orchestration Layer: RKE2 Kubernetes

The main "operating system" for the 5-server cluster. Instead of managing five separate servers, Kubernetes combines them into one powerful distributed system.

- 3-server High-Availability (HA) setup
- Automatic failover if one server fails
- Unified resource management

### Infrastructure Layer

#### Longhorn (Storage)

Self-healing distributed storage system providing:

- Virtual block storage for applications
- Data replication across servers
- Automatic backup and recovery

#### MetalLB (Load Balancer)

Provides external IP addresses from the 172.16.86.x network:

- Stable IP addresses for services
- LoadBalancer service type support
- Layer 2 mode for bare-metal clusters

#### Ingress-Nginx (Traffic Router)

Single entry point for all applications:

- Routes traffic based on hostname (e.g., clearml.ljf.home)
- SSL/TLS termination
- Path-based routing

#### Cert-Manager (Certificate Management)

Automatic SSL/TLS certificate provisioning:

- Let's Encrypt integration
- Automatic certificate renewal
- Secure HTTPS for all services

### Application Layer

#### MinIO (Private S3 Storage)

- URL: <https://minio.ljf.home>
- S3-compatible object storage
- High-performance file storage for ML artifacts
- Stores models, datasets, and experiment results

#### ClearML (MLOps Platform)

- URL: <https://clearml.ljf.home>
- Complete ML experiment tracking
- Model registry and versioning
- Pipeline orchestration
- Resource monitoring

#### n8n (Workflow Automation)

- URL: <https://n8n.ljf.home>
- Visual workflow builder (Zapier alternative)
- Connects all services together
- Automates ML pipelines and notifications

## Capabilities

Once deployed, you'll have a fully functional private MLOps platform:

- Run ML experiments from your laptop with automatic tracking via ClearML
- Store massive datasets and models in high-performance MinIO S3 storage
- Access all tools securely via browser at ljf.home domain addresses
- Create automated workflows with n8n for complete ML pipeline orchestration
- Host and serve AI/ML models as live API endpoints
- Full control over data and infrastructure without cloud dependencies

## Possible solution deployment  

```yaml
# -----------------------------------------------------------------
# 1. CORE SERVICES (Longhorn, MetalLB, Cert-Manager)
# -----------------------------------------------------------------
- name: "K8S APPS | Patch kube-proxy for strictARP (Required by MetalLB)"
  kubernetes.core.k8s_json_patch:
    kind: ConfigMap
    name: kube-proxy
    namespace: kube-system
    patch:
      - op: replace
        path: /data/config.conf
        value: |
          apiVersion: kubeproxy.config.k8s.io/v1alpha1
          kind: KubeProxyConfiguration
          mode: "ipvs"
          ipvs:
            strictARP: true

- name: "K8S APPS | Add Longhorn Helm repo"
  kubernetes.core.helm_repository:
    name: longhorn
    repo_url: https://charts.longhorn.io
    state: present

- name: "K8S APPS | Install Longhorn chart (Persistent Block Storage)"
  kubernetes.core.helm:
    name: longhorn
    chart_ref: longhorn/longhorn
    release_namespace: longhorn-system
    create_namespace: yes
    state: present
    wait: yes
    wait_timeout: 10m

- name: "K8S APPS | Add MetalLB Helm repo"
  kubernetes.core.helm_repository:
    name: metallb
    repo_url: https://metallb.github.io/metallb
    state: present

- name: "K8S APPS | Install MetalLB chart (Network LoadBalancer)"
  kubernetes.core.helm:
    name: metallb
    chart_ref: metallb/metallb
    release_namespace: metallb-system
    create_namespace: yes
    state: present
    wait: yes

- name: "K8S APPS | Apply MetalLB IPAddressPool configuration"
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: metallb.io/v1beta1
      kind: IPAddressPool
      metadata:
        name: default-pool
        namespace: metallb-system
      spec:
        addresses:
        - "{{ metallb_ip_range }}" # Uses var from inventory.yml

- name: "K8S APPS | Add Cert-Manager Helm repo"
  kubernetes.core.helm_repository:
    name: jetstack
    repo_url: https://charts.jetstack.io
    state: present

- name: "K8S APPS | Install Cert-Manager chart (SSL Certificates)"
  kubernetes.core.helm:
    name: cert-manager
    chart_ref: jetstack/cert-manager
    release_namespace: cert-manager
    create_namespace: yes
    state: present
    wait: yes
    wait_timeout: 5m
    values:
      installCRDs: true # This is critical

- name: "K8S APPS | Create Let's Encrypt Staging ClusterIssuer"
  kubernetes.core.k8s:
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
                class: nginx # Use the built-in RKE2 ingress class

# -----------------------------------------------------------------
# 2. DEPENDENCY (MinIO Object Storage)
# -----------------------------------------------------------------
- name: "K8S APPS | Add MinIO Helm repo"
  kubernetes.core.helm_repository:
    name: minio
    repo_url: https://charts.min.io/
    state: present

- name: "K8S APPS | Install MinIO chart (S3 Object Storage)"
  kubernetes.core.helm:
    name: minio
    chart_ref: minio/minio
    release_namespace: minio
    create_namespace: yes
    state: present
    wait: yes
    wait_timeout: 5m
    values:
      persistence:
        storageClass: "longhorn"
      rootUser: "{{ minio_root_user }}"
      rootPassword: "{{ minio_root_pass }}"
      
      # We no longer use LoadBalancer, we use Ingress
      service:
        type: ClusterIP # Keep it internal
        
      ingress:
        enabled: true
        ingressClassName: "nginx" # Use RKE2's ingress
        hosts:
          - "minio.{{ domain }}"
        annotations:
          cert-manager.io/cluster-issuer: "letsencrypt-staging"

# -----------------------------------------------------------------
# 3. MAIN APPLICATIONS (ClearML & n8n)
# -----------------------------------------------------------------
- name: "K8S APPS | Add ClearML Helm repo"
  kubernetes.core.helm_repository:
    name: clearml
    repo_url: https://allegroai.github.io/clearml-helm-charts
    state: present

- name: "K8S APPS | Install ClearML chart (MLOps Platform)"
  kubernetes.core.helm:
    name: clearml
    chart_ref: clearml/clearml
    release_namespace: clearml
    create_namespace: yes
    state: present
    wait: yes
    wait_timeout: 10m
    values:
      persistence:
        storageClass: "longhorn"
      
      # Configure Ingress for all ClearML services
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

- name: "K8S APPS | Add n8n Helm repo"
  kubernetes.core.helm_repository:
    name: n8n
    repo_url: https://helm.n8n.io
    state: present

- name: "K8S APPS | Install n8n chart (Workflow Automation)"
  kubernetes.core.helm:
    name: n8n
    chart_ref: n8n/n8n
    release_namespace: n8n
    create_namespace: yes
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
        
      # We no longer use LoadBalancer, we use Ingress
      service:
        type: ClusterIP # Keep it internal

      ingress:
        enabled: true
        ingressClassName: "nginx" # Use RKE2's ingress
        hosts:
          - "n8n.{{ domain }}"
        annotations:
          cert-manager.io/cluster-issuer: "letsencrypt-staging"

```
