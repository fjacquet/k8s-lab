---
inclusion: always
---

# Kubernetes Expert Guidance

## Core Architecture

### Control Plane Components

- **kube-apiserver**: REST API endpoint for cluster management
- **etcd**: Consistent key-value store for all cluster data (backup critical!)
- **kube-scheduler**: Assigns pods to nodes based on resource requirements
- **kube-controller-manager**: Runs controller processes (node, replication, endpoints, service account)
- **cloud-controller-manager**: Integrates with cloud provider APIs

### Node Components

- **kubelet**: Agent ensuring containers run in pods
- **kube-proxy**: Network proxy maintaining network rules (can be replaced by CNI like Cilium)
- **Container runtime**: Runs containers (containerd, CRI-O)

## Networking Model

### Requirements

- All pods can communicate with each other without NAT
- All nodes can communicate with all pods without NAT
- Pod sees same IP as others see it

### CNI (Container Network Interface)

- Network plugins implement CNI specification
- Provides pod IP addresses and connectivity
- Examples: Cilium, Calico, Flannel, Weave Net
- Configuration: `/etc/cni/net.d/`

### Service Types

- **ClusterIP**: Internal cluster access only (default)
- **NodePort**: Exposes service on each node's IP at static port
- **LoadBalancer**: Exposes service externally using cloud/bare-metal load balancer
- **ExternalName**: Maps service to DNS name

## Storage Architecture

### Volume Types

- **emptyDir**: Temporary storage, deleted when pod removed
- **hostPath**: Mounts file/directory from host (use with caution)
- **PersistentVolume (PV)**: Cluster-level storage resource
- **PersistentVolumeClaim (PVC)**: Request for storage by user

### Storage Classes

- Dynamic provisioning of PVs
- Define storage types (SSD, HDD, replicated, etc.)
- Reclaim policies: Retain, Delete, Recycle

### CSI (Container Storage Interface)

- Standard for exposing storage systems to Kubernetes
- Enables third-party storage providers
- Examples: Longhorn, Ceph, NFS, cloud provider storage

## Resource Management

### Resource Requests and Limits

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "250m"
  limits:
    memory: "128Mi"
    cpu: "500m"
```

### Quality of Service (QoS)

- **Guaranteed**: Requests = Limits for all containers
- **Burstable**: At least one container has request or limit
- **BestEffort**: No requests or limits set

### LimitRange

- Enforces min/max resource constraints per namespace
- Applies to pods and PVCs

## Workload Resources

### Deployment

- Manages ReplicaSets and pod updates
- Rolling updates and rollbacks
- Declarative updates

### StatefulSet

- For stateful applications
- Stable network identities
- Ordered deployment and scaling
- Persistent storage per pod

### DaemonSet

- Ensures pod runs on all (or selected) nodes
- Use cases: logging, monitoring, network plugins

### Job and CronJob

- Job: Run-to-completion tasks
- CronJob: Scheduled jobs

## Configuration Management

### ConfigMap

- Store non-confidential configuration data
- Can be consumed as environment variables, command-line args, or config files

### Secret

- Store sensitive information (passwords, tokens, keys)
- Base64 encoded (not encrypted by default)
- Enable encryption at rest for production

## Cluster DNS

### CoreDNS

- Default DNS server for Kubernetes
- Provides service discovery
- DNS records: `<service>.<namespace>.svc.cluster.local`

## Best Practices

### High Availability

- Run 3+ control plane nodes
- Use external etcd cluster or stacked etcd
- Load balance API server access
- Backup etcd regularly

### Security

- Enable RBAC (Role-Based Access Control)
- Use Network Policies
- Enable Pod Security Standards
- Rotate certificates regularly
- Scan images for vulnerabilities

### Monitoring and Logging

- Deploy metrics-server for resource metrics
- Use Prometheus for monitoring
- Centralize logs (EFK/ELK stack)
- Monitor control plane components

### Namespace Organization

- Separate environments (dev, staging, prod)
- Apply resource quotas per namespace
- Use labels and selectors for organization
- Implement network policies per namespace
