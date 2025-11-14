# Testing and Validation Guide

This document describes the testing and validation procedures for the RKE2 Lab Automation project.

## Overview

The project includes comprehensive testing scripts to validate:

1. **Pre-deployment** - Connectivity and prerequisites
2. **Post-deployment** - Cluster and service validation
3. **Service accessibility** - HTTPS endpoint testing
4. **Idempotency** - Ensuring playbook can be run multiple times safely

## Test Scripts

### 1. Pre-Deployment Connectivity Test

**Script**: `scripts/pre-deployment-test.sh`

**Purpose**: Validates that all prerequisites are met before running the deployment playbook.

**What it checks**:
- Ansible installation and version
- Inventory file existence
- Required Ansible collections (kubernetes.core)
- Required Ansible roles (lablabs.rke2)
- SSH connectivity to all hosts
- Sudo access on all hosts
- OS version (Ubuntu 24.04 LTS recommended)
- Available disk space
- Available memory
- Swap status (should be disabled for Kubernetes)
- Internet connectivity

**Usage**:

```bash
# Run from project root
./scripts/pre-deployment-test.sh

# Or with custom inventory
INVENTORY_FILE=custom-inventory.yml ./scripts/pre-deployment-test.sh
```

**Expected output**: All checks should pass with green checkmarks (✓)

**When to run**: Before initial deployment and after infrastructure changes

---

### 2. Post-Deployment Cluster Validation

**Script**: `scripts/post-deployment-validation.sh`

**Purpose**: Validates that the RKE2 cluster and all services are deployed correctly.

**What it checks**:

**Cluster Nodes**:
- All 5 nodes are present (3 servers, 2 agents)
- All nodes are in Ready state
- Control plane nodes are correctly labeled

**Infrastructure Services**:
- Longhorn: namespace, pods, StorageClass
- MetalLB: namespace, pods, IPAddressPool, L2Advertisement
- Cert-manager: namespace, pods, ClusterIssuer

**Application Services**:
- MinIO: namespace, pods, ingress with IP
- ClearML: namespace, pods, ingress resources (3 endpoints)
- n8n: namespace, pods, ingress with IP

**Usage**:

```bash
# Run on server node (has kubeconfig)
./scripts/post-deployment-validation.sh

# Or from remote machine with kubeconfig
KUBECONFIG=/path/to/rke2.yaml ./scripts/post-deployment-validation.sh
```

**Expected output**: All checks should pass with green checkmarks (✓)

**When to run**: 
- Immediately after deployment
- After cluster upgrades
- After adding/removing nodes
- When troubleshooting issues

---

### 3. Service Accessibility Test

**Script**: `scripts/service-accessibility-test.sh`

**Purpose**: Tests HTTPS access to all deployed services from the client machine.

**What it checks**:
- Ingress IP addresses are assigned
- DNS resolution for all service hostnames
- HTTPS connectivity to all services
- TLS certificate status

**Services tested**:
- MinIO: `https://minio.ljf.home`
- ClearML Web UI: `https://clearml.ljf.home`
- ClearML API: `https://api.clearml.ljf.home`
- ClearML Files: `https://files.clearml.ljf.home`
- n8n: `https://n8n.ljf.home`

**Usage**:

```bash
# Run from any machine with network access
./scripts/service-accessibility-test.sh

# Or with custom domain
DOMAIN=example.com ./scripts/service-accessibility-test.sh
```

**Prerequisites**:
- DNS configured or `/etc/hosts` entries added
- Network access to ingress IPs

**Expected output**: All services should be accessible (HTTP 200-499)

**When to run**:
- After DNS configuration
- After certificate issuance
- When troubleshooting service access issues
- Before handing off to users

---

## Idempotency Testing

### What is Idempotency?

Idempotency means running the playbook multiple times produces the same result without causing errors or unwanted changes. This is a core principle of Ansible automation.

### Why Test Idempotency?

- Ensures playbook can be safely re-run for updates
- Validates that configuration changes don't break existing deployments
- Confirms that the automation is production-ready
- Allows for incremental updates and fixes

### Idempotency Test Procedure

#### Step 1: Initial Deployment

```bash
# Run the playbook for the first time
ansible-playbook playbook.yml --ask-vault-pass

# Record the output
# Expected: Many "changed" tasks (yellow)
```

#### Step 2: Validate Initial Deployment

```bash
# Run post-deployment validation
./scripts/post-deployment-validation.sh

# All checks should pass
```

#### Step 3: Second Run (Idempotency Check)

```bash
# Run the playbook again without any changes
ansible-playbook playbook.yml --ask-vault-pass

# Record the output
# Expected: Mostly "ok" tasks (green), minimal "changed" tasks
```

**What to look for**:
- ✅ No failed tasks
- ✅ No errors in output
- ✅ Most tasks show "ok" (green)
- ✅ Only expected tasks show "changed" (e.g., gathering facts)
- ✅ Services remain accessible

**Acceptable "changed" tasks**:
- Gathering facts
- Checking service status
- Helm chart checks (may show changed even if no actual changes)

**Unacceptable "changed" tasks**:
- File modifications that shouldn't change
- Service restarts without reason
- Configuration overwrites
- Resource deletions

#### Step 4: Validate After Second Run

```bash
# Run post-deployment validation again
./scripts/post-deployment-validation.sh

# All checks should still pass
# No services should be disrupted
```

#### Step 5: Service Continuity Check

```bash
# Verify services are still accessible
./scripts/service-accessibility-test.sh

# All services should remain accessible
# No downtime should have occurred
```

#### Step 6: Third Run (Confirmation)

```bash
# Run the playbook a third time
ansible-playbook playbook.yml --ask-vault-pass

# Output should be identical to second run
# This confirms true idempotency
```

### Idempotency Test Results

Document your results:

```
Test Date: YYYY-MM-DD
Ansible Version: X.X.X
RKE2 Version: vX.X.X

Run 1 (Initial):
- Changed tasks: XX
- Failed tasks: 0
- Duration: XX minutes

Run 2 (Idempotency):
- Changed tasks: X (only facts/checks)
- Failed tasks: 0
- Duration: XX minutes

Run 3 (Confirmation):
- Changed tasks: X (same as Run 2)
- Failed tasks: 0
- Duration: XX minutes

Result: ✅ PASS - Playbook is idempotent
```

### Common Idempotency Issues

**Issue**: Files are modified on every run
- **Cause**: Template variables change or file permissions not set correctly
- **Fix**: Ensure variables are stable, set explicit file modes

**Issue**: Services restart on every run
- **Cause**: Configuration files show as changed even when identical
- **Fix**: Use `changed_when: false` for check tasks, ensure template output is consistent

**Issue**: Helm charts show as changed
- **Cause**: Helm may report changes even when values are identical
- **Fix**: This is often acceptable; verify actual resources are not changing

**Issue**: Certificates regenerate
- **Cause**: Certificate expiry checks or missing conditions
- **Fix**: Add proper conditions to certificate generation tasks

### Testing Configuration Changes

After confirming idempotency, test that intentional changes work:

1. **Modify a variable** (e.g., change MetalLB IP range)
2. **Run playbook** - Should show changed tasks only for affected resources
3. **Validate** - Changes should be applied correctly
4. **Run again** - Should return to idempotent state

### Automated Idempotency Testing

For CI/CD pipelines:

```bash
#!/bin/bash
# automated-idempotency-test.sh

set -e

echo "Running initial deployment..."
ansible-playbook playbook.yml --ask-vault-pass

echo "Running idempotency check..."
OUTPUT=$(ansible-playbook playbook.yml --ask-vault-pass)

# Count changed tasks (excluding facts)
CHANGED=$(echo "$OUTPUT" | grep -c "changed=" || true)

if [ "$CHANGED" -gt 5 ]; then
    echo "FAIL: Too many changed tasks ($CHANGED)"
    exit 1
fi

echo "PASS: Idempotency confirmed ($CHANGED changed tasks)"
```

---

## Testing Workflow

### Complete Testing Sequence

```bash
# 1. Pre-deployment checks
./scripts/pre-deployment-test.sh

# 2. Deploy the cluster
ansible-playbook playbook.yml --ask-vault-pass

# 3. Validate deployment
./scripts/post-deployment-validation.sh

# 4. Configure DNS/hosts
# Add entries to /etc/hosts or configure DNS

# 5. Test service accessibility
./scripts/service-accessibility-test.sh

# 6. Test idempotency
ansible-playbook playbook.yml --ask-vault-pass
# (Should show minimal changes)

# 7. Validate again
./scripts/post-deployment-validation.sh
./scripts/service-accessibility-test.sh
```

### Troubleshooting Failed Tests

**Pre-deployment test fails**:
- Check SSH keys and connectivity
- Verify Ansible installation
- Install missing collections/roles

**Post-deployment validation fails**:
- Check pod logs: `kubectl logs -n <namespace> <pod-name>`
- Check events: `kubectl get events -n <namespace>`
- Verify resource quotas and limits

**Service accessibility test fails**:
- Verify DNS/hosts configuration
- Check ingress controller logs
- Verify MetalLB IP assignment
- Check firewall rules

**Idempotency test fails**:
- Review changed tasks in output
- Check for dynamic values in templates
- Verify file permissions are set explicitly
- Review handler triggers

---

## Continuous Testing

### Regular Testing Schedule

- **Daily**: Service accessibility tests (automated monitoring)
- **Weekly**: Post-deployment validation (health checks)
- **Monthly**: Full idempotency test (maintenance window)
- **Before upgrades**: All tests (pre-change validation)
- **After upgrades**: All tests (post-change validation)

### Monitoring Integration

Integrate test scripts with monitoring systems:

```bash
# Example: Prometheus node_exporter textfile collector
./scripts/service-accessibility-test.sh > /var/lib/node_exporter/service_tests.prom
```

### Alerting

Set up alerts for:
- Service accessibility failures
- Pod restart loops
- Certificate expiration
- Storage capacity
- Node status changes

---

## Test Script Maintenance

### Making Scripts Executable

```bash
chmod +x scripts/*.sh
```

### Customizing Scripts

All scripts support environment variables for customization:

```bash
# Custom inventory
INVENTORY_FILE=prod-inventory.yml ./scripts/pre-deployment-test.sh

# Custom kubeconfig
KUBECONFIG=/path/to/kubeconfig ./scripts/post-deployment-validation.sh

# Custom domain
DOMAIN=example.com ./scripts/service-accessibility-test.sh
```

### Adding New Tests

When adding new services:

1. Update `post-deployment-validation.sh` to check new namespaces/pods
2. Update `service-accessibility-test.sh` to test new endpoints
3. Document new tests in this file
4. Test the test scripts themselves

---

## References

- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [RKE2 Documentation](https://docs.rke2.io/)
- [Kubernetes Testing Guide](https://kubernetes.io/docs/tasks/debug/)
- [Longhorn Troubleshooting](https://longhorn.io/docs/latest/troubleshooting/)
- [MetalLB Troubleshooting](https://metallb.universe.tf/troubleshooting/)
- [Cert-manager Troubleshooting](https://cert-manager.io/docs/troubleshooting/)
