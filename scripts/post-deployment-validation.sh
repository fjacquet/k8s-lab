#!/bin/bash
# Post-deployment cluster validation script
# Validates RKE2 cluster, infrastructure services, and application deployments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KUBECONFIG="${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"
TIMEOUT=300

echo "=========================================="
echo "Post-Deployment Cluster Validation"
echo "=========================================="
echo ""

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# Function to print section header
print_section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
    echo ""
}

# Function to wait for condition
wait_for_condition() {
    local description=$1
    local command=$2
    local timeout=$3
    local elapsed=0
    
    while ! eval "$command" &> /dev/null; do
        if [ $elapsed -ge $timeout ]; then
            print_status 1 "$description (timeout after ${timeout}s)"
            return 1
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    print_status 0 "$description"
    return 0
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl not found. Please install kubectl or run this script on a server node.${NC}"
    exit 1
fi

# Check if kubeconfig exists
if [ ! -f "$KUBECONFIG" ]; then
    echo -e "${RED}Kubeconfig not found at: $KUBECONFIG${NC}"
    echo "Please set KUBECONFIG environment variable or run on server node."
    exit 1
fi

export KUBECONFIG

# Validate Cluster Nodes
print_section "Cluster Nodes"

NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
if [ "$NODE_COUNT" -eq 5 ]; then
    print_status 0 "All 5 nodes are present"
else
    print_status 1 "Expected 5 nodes, found $NODE_COUNT"
fi

READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || true)
if [ "$READY_NODES" -eq 5 ]; then
    print_status 0 "All nodes are in Ready state"
else
    print_status 1 "Only $READY_NODES nodes are Ready"
fi

SERVER_NODES=$(kubectl get nodes --no-headers -l "node-role.kubernetes.io/control-plane" 2>/dev/null | wc -l)
if [ "$SERVER_NODES" -eq 3 ]; then
    print_status 0 "3 server (control plane) nodes detected"
else
    print_status 1 "Expected 3 server nodes, found $SERVER_NODES"
fi

# Validate Infrastructure Services
print_section "Infrastructure Services - Longhorn"

if kubectl get namespace longhorn-system &> /dev/null; then
    print_status 0 "longhorn-system namespace exists"
else
    print_status 1 "longhorn-system namespace not found"
fi

LONGHORN_PODS=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | wc -l)
LONGHORN_READY=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null | grep -c "Running" || true)
if [ "$LONGHORN_PODS" -gt 0 ] && [ "$LONGHORN_READY" -eq "$LONGHORN_PODS" ]; then
    print_status 0 "All Longhorn pods are Running ($LONGHORN_READY/$LONGHORN_PODS)"
else
    print_status 1 "Longhorn pods not all Running ($LONGHORN_READY/$LONGHORN_PODS)"
fi

if kubectl get storageclass longhorn &> /dev/null; then
    print_status 0 "Longhorn StorageClass exists"
else
    print_status 1 "Longhorn StorageClass not found"
fi

print_section "Infrastructure Services - MetalLB"

if kubectl get namespace metallb-system &> /dev/null; then
    print_status 0 "metallb-system namespace exists"
else
    print_status 1 "metallb-system namespace not found"
fi

METALLB_PODS=$(kubectl get pods -n metallb-system --no-headers 2>/dev/null | wc -l)
METALLB_READY=$(kubectl get pods -n metallb-system --no-headers 2>/dev/null | grep -c "Running" || true)
if [ "$METALLB_PODS" -gt 0 ] && [ "$METALLB_READY" -eq "$METALLB_PODS" ]; then
    print_status 0 "All MetalLB pods are Running ($METALLB_READY/$METALLB_PODS)"
else
    print_status 1 "MetalLB pods not all Running ($METALLB_READY/$METALLB_PODS)"
fi

if kubectl get ipaddresspool -n metallb-system default-pool &> /dev/null; then
    print_status 0 "MetalLB IPAddressPool exists"
else
    print_status 1 "MetalLB IPAddressPool not found"
fi

if kubectl get l2advertisement -n metallb-system default-l2 &> /dev/null; then
    print_status 0 "MetalLB L2Advertisement exists"
else
    print_status 1 "MetalLB L2Advertisement not found"
fi

print_section "Infrastructure Services - Cert-Manager"

if kubectl get namespace cert-manager &> /dev/null; then
    print_status 0 "cert-manager namespace exists"
else
    print_status 1 "cert-manager namespace not found"
fi

CERTMGR_PODS=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | wc -l)
CERTMGR_READY=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | grep -c "Running" || true)
if [ "$CERTMGR_PODS" -gt 0 ] && [ "$CERTMGR_READY" -eq "$CERTMGR_PODS" ]; then
    print_status 0 "All cert-manager pods are Running ($CERTMGR_READY/$CERTMGR_PODS)"
else
    print_status 1 "cert-manager pods not all Running ($CERTMGR_READY/$CERTMGR_PODS)"
fi

if kubectl get clusterissuer letsencrypt-staging &> /dev/null; then
    print_status 0 "Let's Encrypt ClusterIssuer exists"
else
    print_status 1 "Let's Encrypt ClusterIssuer not found"
fi

# Validate Application Services
print_section "Application Services - MinIO"

if kubectl get namespace minio &> /dev/null; then
    print_status 0 "minio namespace exists"
else
    print_status 1 "minio namespace not found"
fi

MINIO_PODS=$(kubectl get pods -n minio --no-headers 2>/dev/null | wc -l)
MINIO_READY=$(kubectl get pods -n minio --no-headers 2>/dev/null | grep -c "Running" || true)
if [ "$MINIO_PODS" -gt 0 ] && [ "$MINIO_READY" -eq "$MINIO_PODS" ]; then
    print_status 0 "All MinIO pods are Running ($MINIO_READY/$MINIO_PODS)"
else
    print_status 1 "MinIO pods not all Running ($MINIO_READY/$MINIO_PODS)"
fi

if kubectl get ingress -n minio &> /dev/null; then
    MINIO_INGRESS_IP=$(kubectl get ingress -n minio -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$MINIO_INGRESS_IP" ]; then
        print_status 0 "MinIO ingress has IP: $MINIO_INGRESS_IP"
    else
        print_status 1 "MinIO ingress has no IP assigned"
    fi
else
    print_status 1 "MinIO ingress not found"
fi

print_section "Application Services - ClearML"

if kubectl get namespace clearml &> /dev/null; then
    print_status 0 "clearml namespace exists"
else
    print_status 1 "clearml namespace not found"
fi

CLEARML_PODS=$(kubectl get pods -n clearml --no-headers 2>/dev/null | wc -l)
CLEARML_READY=$(kubectl get pods -n clearml --no-headers 2>/dev/null | grep -c "Running" || true)
if [ "$CLEARML_PODS" -gt 0 ] && [ "$CLEARML_READY" -eq "$CLEARML_PODS" ]; then
    print_status 0 "All ClearML pods are Running ($CLEARML_READY/$CLEARML_PODS)"
else
    print_status 1 "ClearML pods not all Running ($CLEARML_READY/$CLEARML_PODS)"
fi

CLEARML_INGRESS_COUNT=$(kubectl get ingress -n clearml --no-headers 2>/dev/null | wc -l)
if [ "$CLEARML_INGRESS_COUNT" -ge 3 ]; then
    print_status 0 "ClearML ingress resources exist (webserver, apiserver, fileserver)"
else
    print_status 1 "Expected 3 ClearML ingress resources, found $CLEARML_INGRESS_COUNT"
fi

print_section "Application Services - n8n"

if kubectl get namespace n8n &> /dev/null; then
    print_status 0 "n8n namespace exists"
else
    print_status 1 "n8n namespace not found"
fi

N8N_PODS=$(kubectl get pods -n n8n --no-headers 2>/dev/null | wc -l)
N8N_READY=$(kubectl get pods -n n8n --no-headers 2>/dev/null | grep -c "Running" || true)
if [ "$N8N_PODS" -gt 0 ] && [ "$N8N_READY" -eq "$N8N_PODS" ]; then
    print_status 0 "All n8n pods are Running ($N8N_READY/$N8N_PODS)"
else
    print_status 1 "n8n pods not all Running ($N8N_READY/$N8N_PODS)"
fi

if kubectl get ingress -n n8n &> /dev/null; then
    N8N_INGRESS_IP=$(kubectl get ingress -n n8n -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$N8N_INGRESS_IP" ]; then
        print_status 0 "n8n ingress has IP: $N8N_INGRESS_IP"
    else
        print_status 1 "n8n ingress has no IP assigned"
    fi
else
    print_status 1 "n8n ingress not found"
fi

# Summary
print_section "Validation Summary"

echo "Cluster Status:"
kubectl get nodes
echo ""

echo "All Pods Status:"
kubectl get pods -A | grep -v "Running\|Completed" || echo "All pods are Running or Completed"
echo ""

echo "Ingress Resources:"
kubectl get ingress -A
echo ""

echo -e "${GREEN}Validation complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Configure DNS or /etc/hosts for service access"
echo "2. Run service accessibility tests: ./scripts/service-accessibility-test.sh"
echo ""
