# Ubuntu 24.04 LTS (Noble Numbat)

## System Requirements

### Minimum Specifications
- **Processor**: 1 GHz or faster (64-bit)
- **RAM**: 1 GB minimum (2 GB recommended for servers)
- **Disk Space**: 10 GB minimum
- **Network**: Ethernet adapter required

### Recommended for RKE2 Nodes
- **RAM**: 4 GB minimum (8 GB+ recommended)
- **Disk Space**: 50 GB+ for system and container storage
- **CPU**: 2+ cores per node
- **Network**: Gigabit Ethernet for cluster communication

## Package Management

### APT Commands

```bash
# Update package index
sudo apt update

# Upgrade all packages
sudo apt upgrade

# Install packages
sudo apt install <package-name>

# Install multiple packages
sudo apt install package1 package2 package3

# Remove package
sudo apt remove <package-name>

# Search for packages
apt search <keyword>

# Show package information
apt show <package-name>
```

### Essential Packages for RKE2

```bash
# iSCSI support (required for Longhorn)
sudo apt install open-iscsi

# Basic utilities
sudo apt install curl vim wget

# Certificate management
sudo apt install ca-certificates

# NFS utilities (optional)
sudo apt install nfs-common
```

## Networking

### Netplan Configuration

Ubuntu 24.04 uses Netplan for network configuration:

- Configuration files: `/etc/netplan/*.yaml`
- Apply changes: `sudo netplan apply`
- Test configuration: `sudo netplan try`

### Static IP Example

```yaml
network:
  version: 2
  ethernets:
    eth0:
      addresses:
        - 192.168.1.100/24
      gateway4: 192.168.1.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
```

## System Configuration

### Disable Swap (Required for Kubernetes)

```bash
# Disable swap immediately
sudo swapoff -a

# Disable swap permanently
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

### Enable Required Services

```bash
# Enable and start iSCSI (for Longhorn)
sudo systemctl enable iscsid
sudo systemctl start iscsid
```

### Firewall Configuration

```bash
# Install UFW if needed
sudo apt install ufw

# Allow SSH
sudo ufw allow 22/tcp

# RKE2 required ports
sudo ufw allow 9345/tcp  # Server registration
sudo ufw allow 6443/tcp  # Kubernetes API
sudo ufw allow 10250/tcp # Kubelet metrics
sudo ufw allow 2379:2380/tcp # etcd (server nodes only)

# Enable firewall
sudo ufw enable
```

## Automatic Updates

### Configure Unattended Upgrades

```bash
# Install package
sudo apt install unattended-upgrades

# Configure
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

### Configuration File

Edit `/etc/apt/apt.conf.d/50unattended-upgrades`:

```conf
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
};

Unattended-Upgrade::Automatic-Reboot "false";
```

## Ansible Considerations

### Connection Settings

```yaml
# inventory.yml
all:
  vars:
    ansible_user: ubuntu
    ansible_become: yes
    ansible_become_method: sudo
    ansible_python_interpreter: /usr/bin/python3
```

### Common Ansible Tasks

```yaml
# Update apt cache
- name: Update apt cache
  apt:
    update_cache: yes
    cache_valid_time: 3600

# Install packages
- name: Install required packages
  apt:
    name:
      - open-iscsi
      - curl
      - vim
    state: present

# Disable swap
- name: Disable swap
  shell: swapoff -a
  when: ansible_swaptotal_mb > 0

- name: Remove swap from fstab
  lineinfile:
    path: /etc/fstab
    regexp: '.*swap.*'
    state: absent
```

## Security Best Practices

### SSH Hardening

```bash
# Disable root login
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Disable password authentication (use keys)
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Restart SSH
sudo systemctl restart sshd
```

### User Management

```bash
# Create user with sudo privileges
sudo adduser <username>
sudo usermod -aG sudo <username>

# Add SSH key
sudo -u <username> mkdir -p /home/<username>/.ssh
sudo -u <username> chmod 700 /home/<username>/.ssh
```

## Troubleshooting

### Common Issues

**Package lock errors:**
```bash
# Wait for other apt processes or kill them
sudo killall apt apt-get
sudo rm /var/lib/apt/lists/lock
sudo rm /var/cache/apt/archives/lock
sudo rm /var/lib/dpkg/lock*
sudo dpkg --configure -a
```

**Network issues:**
```bash
# Check network status
ip addr show
sudo netplan --debug apply

# Test connectivity
ping -c 4 8.8.8.8
```

**Service issues:**
```bash
# Check service status
sudo systemctl status <service-name>

# View logs
sudo journalctl -u <service-name> -f
```

## Version-Specific Notes

### Ubuntu 24.04 (Noble Numbat)

- **Release Date**: April 2024
- **Support**: 5 years (until April 2029)
- **Kernel**: Linux 6.8+
- **Python**: 3.12 default
- **systemd**: 255+

### Testing Proposed Updates

```bash
# Install from proposed repository
sudo apt-get install -t noble-proposed <package-name>
```

## References

- Official Documentation: https://documentation.ubuntu.com/server/
- Release Notes: https://wiki.ubuntu.com/NobleNumbat/ReleaseNotes
- Security Updates: https://ubuntu.com/security/notices
