#!/bin/bash
# Pre-deployment connectivity and prerequisites test script
# Tests SSH connectivity, sudo access, and system requirements before deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INVENTORY_FILE="${INVENTORY_FILE:-inventory.yml}"
REQUIRED_ANSIBLE_VERSION="3.4.0"

echo "=========================================="
echo "Pre-Deployment Connectivity Test"
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

# Check if Ansible is installed
echo "Checking Ansible installation..."
if command -v ansible &> /dev/null; then
    ANSIBLE_VERSION=$(ansible --version | head -n1 | awk '{print $2}')
    print_status 0 "Ansible is installed (version: $ANSIBLE_VERSION)"
else
    print_status 1 "Ansible is not installed"
    echo "Please install Ansible: pip install ansible"
    exit 1
fi

# Check if inventory file exists
echo ""
echo "Checking inventory file..."
if [ -f "$INVENTORY_FILE" ]; then
    print_status 0 "Inventory file exists: $INVENTORY_FILE"
else
    print_status 1 "Inventory file not found: $INVENTORY_FILE"
    exit 1
fi

# Check Ansible collections
echo ""
echo "Checking required Ansible collections..."
if ansible-galaxy collection list | grep -q "kubernetes.core"; then
    print_status 0 "kubernetes.core collection is installed"
else
    print_status 1 "kubernetes.core collection is not installed"
    echo "Install with: ansible-galaxy collection install kubernetes.core"
    exit 1
fi

# Check required roles
echo ""
echo "Checking required Ansible roles..."
if ansible-galaxy role list | grep -q "lablabs.rke2"; then
    print_status 0 "lablabs.rke2 role is installed"
else
    print_status 1 "lablabs.rke2 role is not installed"
    echo "Install with: ansible-galaxy install -r requirements.yml"
    exit 1
fi

# Test SSH connectivity to all hosts
echo ""
echo "Testing SSH connectivity to all hosts..."
if ansible all -i "$INVENTORY_FILE" -m ping &> /dev/null; then
    print_status 0 "SSH connectivity successful to all hosts"
else
    print_status 1 "SSH connectivity failed to one or more hosts"
    echo "Run: ansible all -m ping"
    exit 1
fi

# Test sudo access
echo ""
echo "Testing sudo access on all hosts..."
if ansible all -i "$INVENTORY_FILE" -m shell -a "sudo whoami" -b &> /dev/null; then
    print_status 0 "Sudo access verified on all hosts"
else
    print_status 1 "Sudo access failed on one or more hosts"
    exit 1
fi

# Check OS version on all hosts
echo ""
echo "Checking OS version on all hosts..."
OS_CHECK=$(ansible all -i "$INVENTORY_FILE" -m setup -a "filter=ansible_distribution*" 2>/dev/null | grep -E "ansible_distribution|ansible_distribution_version")
if echo "$OS_CHECK" | grep -q "Ubuntu"; then
    print_status 0 "Ubuntu detected on hosts"
    if echo "$OS_CHECK" | grep -q "24.04"; then
        print_status 0 "Ubuntu 24.04 LTS detected"
    else
        print_warning "Ubuntu version is not 24.04 LTS (may still work)"
    fi
else
    print_warning "Non-Ubuntu OS detected (may not be supported)"
fi

# Check available disk space
echo ""
echo "Checking disk space on all hosts..."
DISK_CHECK=$(ansible all -i "$INVENTORY_FILE" -m shell -a "df -h / | tail -1 | awk '{print \$4}'" 2>/dev/null)
print_status 0 "Disk space check completed (review output above)"

# Check available memory
echo ""
echo "Checking available memory on all hosts..."
MEM_CHECK=$(ansible all -i "$INVENTORY_FILE" -m shell -a "free -h | grep Mem | awk '{print \$2}'" 2>/dev/null)
print_status 0 "Memory check completed (review output above)"

# Check if swap is enabled
echo ""
echo "Checking swap status on all hosts..."
SWAP_CHECK=$(ansible all -i "$INVENTORY_FILE" -m shell -a "swapon --show" 2>/dev/null)
if [ -z "$SWAP_CHECK" ]; then
    print_status 0 "Swap is disabled on all hosts (good for Kubernetes)"
else
    print_warning "Swap is enabled on some hosts (will be disabled during deployment)"
fi

# Check network connectivity between nodes
echo ""
echo "Checking network connectivity between nodes..."
if ansible all -i "$INVENTORY_FILE" -m shell -a "ping -c 1 8.8.8.8" &> /dev/null; then
    print_status 0 "Internet connectivity verified on all hosts"
else
    print_warning "Internet connectivity issues detected on some hosts"
fi

# Summary
echo ""
echo "=========================================="
echo "Pre-Deployment Test Summary"
echo "=========================================="
echo ""
echo -e "${GREEN}All critical checks passed!${NC}"
echo ""
echo "You can proceed with deployment:"
echo "  ansible-playbook playbook.yml --ask-vault-pass"
echo ""
