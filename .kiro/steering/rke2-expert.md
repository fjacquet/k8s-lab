---
inclusion: always
---

# RKE2 Expert Guidance

## Overview

RKE2 (Rancher Kubernetes Engine 2) is a production-ready Kubernetes distribution designed for security and compliance, particularly for U.S. Federal Government sector with CIS benchmark compliance and FIPS 140-2 support.

## Installation Best Practices

### Server Node Installation

- Use the official installation script: `curl -sfL https://get.rke2.io | sh -`
- Enable and start the service: `systemctl enable rke2-server.service && systemctl start rke2-server.service`
- Configuration file location: `/etc/rancher/rke2/config.yaml`
- Kubeconfig location: `/etc/rancher/rke2/rke2.yaml`
- Node token location: `/var/lib/rancher/rke2/server/node-token`

### Agent Node Installation

- Install with agent type: `curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -`
- Enable and start: `systemctl enable rke2-agent.service && systemctl start rke2-agent.service`
- Required config: server URL (port 9345) and token

### High Availability Setup

- Use odd number of server nodes (3, 5, 7) for etcd quorum
- Configure shared token across all server nodes
- Set TLS SANs for all server IPs and domain names
- First server initializes cluster, subsequent servers join via `server:` parameter

## Configuration Patterns

### Server Config Template

```yaml
# /etc/rancher/rke2/config.yaml
token: <shared-cluster-secret>
tls-san:
  - <domain-name>
  - <server-ip-1>
  - <server-ip-2>
disable:
  - rke2-service-lb  # Disable if using MetalLB
```

### Agent Config Template

```yaml
# /etc/rancher/rke2/config.yaml
server: https://<server-ip>:9345
token: <node-token-from-server>
```

## Network Configuration

### Disabling Default Components

- Disable default service load balancer when using MetalLB: `disable: [rke2-service-lb]`
- Disable default CNI when using alternative: `cni: none` or specify custom CNI

### Dual-Stack Networking

```yaml
cluster-cidr: "10.42.0.0/16,2001:cafe:42::/56"
service-cidr: "10.43.0.0/16,2001:cafe:43::/112"
```

## Critical Requirements

### Prerequisites

- Open ports: 9345 (server registration), 6443 (Kubernetes API), 10250 (kubelet)
- Disable swap on all nodes
- Install required packages: `open-iscsi` for storage solutions like Longhorn

### Service Management

- Monitor logs: `journalctl -u rke2-server -f` or `journalctl -u rke2-agent -f`
- Service files: `/etc/systemd/system/rke2-server.service` or `rke2-agent.service`

### kubectl Access

```bash
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get nodes
```

## Add-on Management

### Disabling Add-ons

```yaml
disable:
  - rke2-coredns
  - rke2-metrics-server
  - rke2-ingress-nginx
```

### Helm Integration

- RKE2 includes Helm controller for managing charts
- Charts placed in `/var/lib/rancher/rke2/server/manifests/` are auto-deployed

## Upgrade Strategy

- Use system-upgrade-controller for automated upgrades
- Create separate upgrade plans for server and agent nodes
- Server nodes upgrade with concurrency: 1
- Agent nodes can upgrade with higher concurrency
- Always upgrade server nodes before agent nodes

## Security Considerations

- RKE2 runs components as systemd services (not containers)
- CIS hardened by default
- Pod Security Standards enforced
- Network policies supported
- Secrets encryption at rest available
