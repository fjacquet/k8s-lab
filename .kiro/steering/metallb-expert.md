---
inclusion: always
---

# MetalLB Expert Guidance

## Overview

MetalLB is a load-balancer implementation for bare metal Kubernetes clusters using standard routing protocols. It provides LoadBalancer service type functionality without requiring cloud provider integration.

## Operating Modes

### Layer 2 Mode

- Uses ARP (IPv4) or NDP (IPv6) to announce IPs
- Simple setup, no special hardware required
- Single node handles all traffic (no load distribution)
- Automatic failover on node failure
- Best for: Small clusters, simple setups

### BGP Mode

- Announces IPs via BGP protocol
- True load balancing across multiple nodes
- Requires BGP-capable router
- More complex setup
- Best for: Production, large scale, true HA

## Installation Methods

### Helm Installation (Recommended)

```bash
helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb \
  --namespace metallb-system \
  --create-namespace
```

### Kustomize Installation

```yaml
# kustomization.yml
namespace: metallb-system
resources:
  - github.com/metallb/metallb/config/native?ref=main
```

### Manifest Installation

```bash
kubectl apply -f \
  https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-native.yaml
```

## Configuration Resources

### IPAddressPool

Defines IP ranges for LoadBalancer services

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.1.200-192.168.1.210
    - 192.168.1.220/32
  autoAssign: true # Automatically assign IPs from this pool
```

### L2Advertisement

Announces IPs in Layer 2 mode

```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - default-pool
  nodeSelectors:
    - matchLabels:
        kubernetes.io/hostname: opt1
```

### BGPAdvertisement

Announces IPs via BGP

```yaml
apiVersion: metallb.io/v1beta1
kind: BGPAdvertisement
metadata:
  name: default-bgp
  namespace: metallb-system
spec:
  ipAddressPools:
    - default-pool
  peers:
    - my-bgp-peer
  communities:
    - 65000:100
  localPref: 100
```

### BGPPeer

Defines BGP peering configuration

```yaml
apiVersion: metallb.io/v1beta1
kind: BGPPeer
metadata:
  name: my-bgp-peer
  namespace: metallb-system
spec:
  myASN: 64500
  peerASN: 64501
  peerAddress: 192.168.1.1
  peerPort: 179
```

## Service Configuration

### Basic LoadBalancer Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 8080
```

### Request Specific IP

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.1.200 # Deprecated, use annotations
  selector:
    app: my-app
  ports:
    - port: 80
```

### Using Annotations

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    metallb.universe.tf/loadBalancerIPs: 192.168.1.200
    metallb.universe.tf/address-pool: default-pool
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
    - port: 80
```

## Integration with RKE2

### Disable RKE2 Service LoadBalancer

```yaml
# /etc/rancher/rke2/config.yaml
disable:
  - rke2-service-lb
```

### Configure Strict ARP (Required for L2 Mode)

```bash
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system
```

Or using kubernetes.core.k8s module:

```yaml
- name: Enable strict ARP for kube-proxy
  kubernetes.core.k8s:
    state: patched
    kind: ConfigMap
    namespace: kube-system
    name: kube-proxy
    definition:
      data:
        config.conf: |
          mode: "ipvs"
          ipvs:
            strictARP: true
```

## Advanced Configuration

### Multiple IP Pools

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: production-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.1.200-192.168.1.210
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: development-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.2.200-192.168.2.210
```

### optSpecific Advertisements

```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: optspecific
  namespace: metallb-system
spec:
  ipAddressPools:
    - default-pool
  nodeSelectors:
    - matchLabels:
        optrole: edge
```

### Service-Specific Pools

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
  annotations:
    metallb.universe.tf/address-pool: production-pool
spec:
  type: LoadBalancer
```

## Troubleshooting

### Check MetalLB Status

```bash
kubectl get pods -n metallb-system
kubectl logs -n metallb-system -l app=metallb
```

### Verify Configuration

```bash
kubectl get ipaddresspool -n metallb-system
kubectl get l2advertisement -n metallb-system
kubectl get bgpadvertisement -n metallb-system
```

### Check Service IP Assignment

```bash
kubectl get svc
kubectl describe svc <service-name>
```

### Common Issues

#### Service Stuck in Pending

- Check IPAddressPool has available IPs
- Verify L2Advertisement or BGPAdvertisement exists
- Check MetalLB controller logs

#### IP Not Reachable

- Verify IP range is in same subnet as nodes
- Check firewall rules
- For L2: Verify strictARP is enabled
- For BGP: Check BGP peering status

#### Multiple Services Same IP

- Use `spec.loadBalancerIP` or annotations to request specific IPs
- Check for IP conflicts in pool definitions

## Best Practices

### IP Planning

- Reserve IP range outside DHCP scope
- Use contiguous IP ranges when possible
- Document IP assignments
- Plan for growth

### High Availability

- Use multiple nodes for L2 advertisements
- Configure BGP for true load distribution
- Test failover scenarios
- Monitor IP assignments

### Security

- Restrict IP pools to appropriate namespaces
- Use network policies with LoadBalancer services
- Audit IP assignments regularly
- Secure BGP peering with passwords

### Operations

- Monitor MetalLB controller and speaker logs
- Set up alerts for IP pool exhaustion
- Document configuration changes
- Test before production deployment
