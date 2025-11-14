---
inclusion: always
---

# Cilium Expert Guidance

## Overview

Cilium is an eBPF-based networking, security, and observability solution for cloud-native environments. It provides high-performance networking and advanced security features without requiring kernel modifications.

## Core Features

### Networking

- **CNI Plugin**: Provides pod networking and IP address management
- **Service Load Balancing**: Can replace kube-proxy with eBPF-based load balancing
- **Network Policies**: Layer 3/4 and Layer 7 (HTTP, gRPC, Kafka) policies
- **Multi-cluster**: Connect multiple Kubernetes clusters
- **Bandwidth Management**: Traffic shaping and QoS

### Security

- **Identity-based Security**: Uses workload identity instead of IP addresses
- **Transparent Encryption**: IPsec or WireGuard for pod-to-pod encryption
- **Network Policies**: Fine-grained ingress/egress rules
- **DNS-aware Policies**: Control access based on DNS names
- **API-aware Policies**: Layer 7 filtering (HTTP methods, paths, headers)

### Observability

- **Hubble**: Network and security observability platform
- **Flow Logs**: Detailed network flow information
- **Service Map**: Visualize service dependencies
- **Metrics**: Prometheus-compatible metrics

## Installation Methods

### Helm Installation (Recommended)

```bash
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --version 1.18.2 \
  --namespace kube-system
```

### Installation Options by Platform

#### Standard Kubernetes

```bash
helm install cilium cilium/cilium --version 1.18.2 \
  --namespace kube-system
```

#### K3s/RKE2

- Disable default CNI: `--flannel-backend=none --disable-network-policy`
- Install Cilium after cluster initialization

#### AKS (Azure)

```bash
# BYOCNI mode
helm install cilium cilium/cilium --version 1.18.2 \
  --namespace kube-system \
  --set aksbyocni.enabled=true
```

#### Kind

```yaml
# kind-config.yaml
networking:
  disableDefaultCNI: true
```

## Configuration Patterns

### Basic Configuration

```yaml
# values.yaml
ipam:
  mode: kubernetes  # or cluster-pool

kubeProxyReplacement: true  # Replace kube-proxy

hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
```

### kube-proxy Replacement

```yaml
kubeProxyReplacement: true
k8sServiceHost: <API_SERVER_IP>
k8sServicePort: <API_SERVER_PORT>
```

### Encryption

```yaml
# IPsec
encryption:
  enabled: true
  type: ipsec

# WireGuard (preferred)
encryption:
  enabled: true
  type: wireguard
```

### Hubble Observability

```yaml
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
  metrics:
    enabled:
      - dns
      - drop
      - tcp
      - flow
      - icmp
      - http
```

## CNI Chaining

### With Calico

```yaml
# ConfigMap for CNI chaining
cni:
  chainingMode: generic-veth
  customConf: true
  configMap: cni-configuration
```

### With Azure CNI

```yaml
cni:
  chainingMode: azure
```

### With AWS VPC CNI

```yaml
cni:
  chainingMode: aws-cni
```

## Network Policies

### Layer 3/4 Policy

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-frontend
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: frontend
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
```

### Layer 7 HTTP Policy

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: http-policy
spec:
  endpointSelector:
    matchLabels:
      app: api
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: frontend
      toPorts:
        - ports:
            - port: "80"
              protocol: TCP
          rules:
            http:
              - method: "GET"
                path: "/api/v1/.*"
```

### DNS-based Policy

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: dns-policy
spec:
  endpointSelector:
    matchLabels:
      app: myapp
  egress:
    - toFQDNs:
        - matchName: "api.example.com"
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
```

## Connectivity Testing

### Deploy Test Suite

```bash
kubectl create ns cilium-test
kubectl apply -n cilium-test -f \
  https://raw.githubusercontent.com/cilium/cilium/1.18.2/examples/kubernetes/connectivity-check/connectivity-check.yaml
```

### Run Connectivity Test

```bash
cilium connectivity test
```

## Troubleshooting

### Check Cilium Status

```bash
cilium status
cilium status --wait
```

### Check Agent Logs

```bash
kubectl -n kube-system logs -l k8s-app=cilium
```

### Check Connectivity

```bash
cilium connectivity test
```

### Hubble Observe

```bash
hubble observe
hubble observe --namespace default
hubble observe --pod mypod
```

### Common Issues

#### Pods Not Getting IPs

- Check IPAM mode and available IP ranges
- Verify CNI configuration
- Check cilium-operator logs

#### Network Policy Not Working

- Verify policy syntax
- Check endpoint labels match
- Use `hubble observe` to see dropped packets

#### kube-proxy Replacement Issues

- Ensure `k8sServiceHost` and `k8sServicePort` are set correctly
- Verify eBPF programs are loaded: `cilium status`
- Check for conflicting kube-proxy instances

## Performance Tuning

### eBPF Host Routing

```yaml
tunnel: disabled
autoDirectNodeRoutes: true
ipv4NativeRoutingCIDR: <CLUSTER_CIDR>
```

### Bandwidth Manager

```yaml
bandwidthManager:
  enabled: true
```

### Connection Tracking

```yaml
conntrackGCInterval: "30s"
conntrackGCMaxInterval: "1m"
```

## Best Practices

### Installation

- Always specify version in Helm install
- Use `--wait` flag to ensure complete deployment
- Test connectivity after installation

### Security

- Enable encryption for sensitive workloads
- Use identity-based policies over IP-based
- Implement Layer 7 policies for HTTP/gRPC services
- Enable Hubble for visibility

### Operations

- Monitor Cilium agent and operator logs
- Set up Prometheus metrics collection
- Use Hubble UI for troubleshooting
- Keep Cilium updated for security patches

### Integration

- When replacing kube-proxy, test thoroughly
- For CNI chaining, ensure proper plugin order
- Verify compatibility with cluster version
