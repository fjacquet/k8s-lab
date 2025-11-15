# RKE2 Installation Fix Instructions

## Issues Fixed

1. **HA Mode Configuration**: Enabled `rke2_ha_mode: true` for proper 3-server HA cluster
2. **Keepalived**: Added keepalived package installation for HA VIP management
3. **API VIP**: Configured `rke2_api_ip: 172.16.86.10` as the Virtual IP for the cluster
4. **Group Names**: Explicitly set `rke2_servers_group_name` and `rke2_agents_group_name`
5. **Secure Token**: Added RKE2 cluster token to vault variables
6. **DNS Configuration**: Added DNS server and domain configuration for all nodes

## Changes Made

### 1. inventory.yml

- Enabled HA mode: `rke2_ha_mode: true`
- Enabled keepalived: `rke2_ha_mode_keepalived: true`
- Set VIP: `rke2_api_ip: 172.16.86.20`
- Added VIP to TLS SANs
- Added secure token reference: `rke2_token: "{{ vault_rke2_token }}"`
- Added DNS configuration variables

### 2. roles/common/tasks/main.yml

- Added `keepalived` package installation
- Added `resolvconf` package and configuration
- Configured DNS nameserver and search domain

### 3. vars/secrets.yml.sample

- Added `vault_rke2_token` variable

### 4. playbook.yml

- Added `vars_files: - vars/secrets.yml` to all plays

## Required Actions

### 1. Update Vault Secrets

Edit the encrypted secrets file:

```bash
ansible-vault edit vars/secrets.yml
```

Add this line at the top (generate a secure random token):

```yaml
vault_rke2_token: "$(openssl rand -base64 32)"
```

Or manually add:

```yaml
vault_rke2_token: "your-secure-random-token-here"
```

### 2. Verify Configuration

Check that your VIP (172.16.86.10) is:

- Not currently in use
- In the same subnet as your nodes
- Accessible from all nodes

### 3. Run Deployment

```bash
ansible-playbook playbook.yml --ask-vault-pass
```

## What This Fixes

### Before (Issues)

- RKE2 installed in single-server mode (not HA)
- No VIP configured for API access
- Kubeconfig not properly accessible
- Services not starting correctly

### After (Fixed)

- RKE2 HA cluster with 3 servers
- Keepalived managing VIP (172.16.86.10)
- All servers can become leader
- Kubeconfig available at `/etc/rancher/rke2/rke2.yaml`
- Services properly started and accessible
- DNS properly configured on all nodes

## Verification After Deployment

On any master node:

```bash
# Check RKE2 service
sudo systemctl status rke2-server

# Check keepalived
sudo systemctl status keepalived

# Verify VIP
ip addr show | grep 172.16.86.10

# Test kubectl access
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get nodes

# Check DNS
cat /etc/resolv.conf
```

## Troubleshooting

If RKE2 still doesn't work:

1. **Check keepalived logs**:

   ```bash
   sudo journalctl -u keepalived -f
   ```

2. **Check RKE2 logs**:

   ```bash
   sudo journalctl -u rke2-server -f
   ```

3. **Verify network connectivity**:

   ```bash
   # From each node, ping the VIP
   ping 172.16.86.10
   
   # Check if port 6443 is accessible
   nc -zv 172.16.86.10 6443
   ```

4. **Check DNS resolution**:

   ```bash
   nslookup ljf.home 172.16.86.10
   ```

## Architecture

```
                    VIP: 172.16.86.10
                           |
        +------------------+------------------+
        |                  |                  |
    opt1 (Master)      opt2 (Master)     opt3 (Master)
   172.16.86.11       172.16.86.12      172.16.86.13
        |                  |                  |
        +------------------+------------------+
                           |
        +------------------+------------------+
        |                                     |
    opt4 (Worker)                        opt5 (Worker)
   172.16.86.14                         172.16.86.15
```

- **Keepalived** manages the VIP across the 3 masters
- **etcd** runs on all 3 masters (HA quorum)
- **Kubernetes API** accessible via VIP
- **Workers** connect to VIP for cluster join
- **DNS** resolves to 172.16.86.10 with ljf-home domain
