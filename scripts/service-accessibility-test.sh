#!/bin/bash
# Service accessibility test script
# Tests HTTPS access to all deployed services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KUBECONFIG="${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"
DOMAIN="${DOMAIN:-ljf.home}"
TIMEOUT=10

echo "=========================================="
echo "Service Accessibility Test"
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

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Function to print section header
print_section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
    echo ""
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl not found. Please install kubectl or run this script on a server node.${NC}"
    exit 1
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo -e "${RED}curl not found. Please install curl.${NC}"
    exit 1
fi

export KUBECONFIG

# Get ingress IPs
print_section "Ingress IP Addresses"

MINIO_IP=$(kubectl get ingress -n minio -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null)
CLEARML_IP=$(kubectl get ingress -n clearml -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null)
N8N_IP=$(kubectl get ingress -n n8n -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -n "$MINIO_IP" ]; then
    echo "MinIO Ingress IP: $MINIO_IP"
else
    print_warning "MinIO ingress IP not found"
fi

if [ -n "$CLEARML_IP" ]; then
    echo "ClearML Ingress IP: $CLEARML_IP"
else
    print_warning "ClearML ingress IP not found"
fi

if [ -n "$N8N_IP" ]; then
    echo "n8n Ingress IP: $N8N_IP"
else
    print_warning "n8n ingress IP not found"
fi

# Check DNS resolution
print_section "DNS Resolution"

SERVICES=(
    "minio.$DOMAIN"
    "clearml.$DOMAIN"
    "api.clearml.$DOMAIN"
    "files.clearml.$DOMAIN"
    "n8n.$DOMAIN"
)

DNS_CONFIGURED=true
for service in "${SERVICES[@]}"; do
    if host "$service" &> /dev/null; then
        RESOLVED_IP=$(host "$service" | grep "has address" | awk '{print $4}')
        print_status 0 "$service resolves to $RESOLVED_IP"
    else
        print_status 1 "$service does not resolve"
        DNS_CONFIGURED=false
    fi
done

if [ "$DNS_CONFIGURED" = false ]; then
    echo ""
    print_warning "DNS not configured. Add entries to /etc/hosts:"
    echo ""
    [ -n "$MINIO_IP" ] && echo "$MINIO_IP minio.$DOMAIN"
    [ -n "$CLEARML_IP" ] && echo "$CLEARML_IP clearml.$DOMAIN api.clearml.$DOMAIN files.clearml.$DOMAIN"
    [ -n "$N8N_IP" ] && echo "$N8N_IP n8n.$DOMAIN"
    echo ""
fi

# Test HTTPS connectivity
print_section "HTTPS Connectivity Tests"

# MinIO
echo "Testing MinIO (https://minio.$DOMAIN)..."
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT "https://minio.$DOMAIN" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 500 ]; then
    print_status 0 "MinIO is accessible (HTTP $HTTP_CODE)"
else
    print_status 1 "MinIO is not accessible (HTTP $HTTP_CODE)"
fi

# ClearML Web UI
echo "Testing ClearML Web UI (https://clearml.$DOMAIN)..."
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT "https://clearml.$DOMAIN" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 500 ]; then
    print_status 0 "ClearML Web UI is accessible (HTTP $HTTP_CODE)"
else
    print_status 1 "ClearML Web UI is not accessible (HTTP $HTTP_CODE)"
fi

# ClearML API Server
echo "Testing ClearML API Server (https://api.clearml.$DOMAIN)..."
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT "https://api.clearml.$DOMAIN" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 500 ]; then
    print_status 0 "ClearML API Server is accessible (HTTP $HTTP_CODE)"
else
    print_status 1 "ClearML API Server is not accessible (HTTP $HTTP_CODE)"
fi

# ClearML File Server
echo "Testing ClearML File Server (https://files.clearml.$DOMAIN)..."
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT "https://files.clearml.$DOMAIN" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 500 ]; then
    print_status 0 "ClearML File Server is accessible (HTTP $HTTP_CODE)"
else
    print_status 1 "ClearML File Server is not accessible (HTTP $HTTP_CODE)"
fi

# n8n
echo "Testing n8n (https://n8n.$DOMAIN)..."
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT "https://n8n.$DOMAIN" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 500 ]; then
    print_status 0 "n8n is accessible (HTTP $HTTP_CODE)"
else
    print_status 1 "n8n is not accessible (HTTP $HTTP_CODE)"
fi

# Test certificate status
print_section "TLS Certificate Status"

for service in "${SERVICES[@]}"; do
    CERT_INFO=$(echo | openssl s_client -connect "$service:443" -servername "$service" 2>/dev/null | openssl x509 -noout -subject -issuer 2>/dev/null || echo "")
    if [ -n "$CERT_INFO" ]; then
        if echo "$CERT_INFO" | grep -q "Let's Encrypt"; then
            print_status 0 "$service has Let's Encrypt certificate"
        else
            print_warning "$service has certificate (not Let's Encrypt)"
        fi
    else
        print_status 1 "$service certificate check failed"
    fi
done

# Summary
print_section "Service Access URLs"

echo "MinIO:              https://minio.$DOMAIN"
echo "ClearML Web UI:     https://clearml.$DOMAIN"
echo "ClearML API:        https://api.clearml.$DOMAIN"
echo "ClearML Files:      https://files.clearml.$DOMAIN"
echo "n8n:                https://n8n.$DOMAIN"
echo ""

echo -e "${GREEN}Service accessibility test complete!${NC}"
echo ""

if [ "$DNS_CONFIGURED" = false ]; then
    print_warning "Configure DNS or /etc/hosts before accessing services from other machines"
fi

echo ""
echo "Note: Using -k flag with curl to accept self-signed/staging certificates"
echo "For production, switch to Let's Encrypt production issuer"
echo ""
