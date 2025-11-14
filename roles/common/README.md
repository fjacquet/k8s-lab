Common Role
===========

Prepares Ubuntu 24.04 LTS nodes with prerequisites for RKE2 Kubernetes cluster deployment.

Requirements
------------

- Ubuntu 24.04 LTS target nodes
- Ansible 3.4.0+ (ansible-core 2.20.0+)
- Sudo/root access on target nodes

Role Variables
--------------

This role uses Ansible facts and does not require additional variables:

- `ansible_distribution`: Used to verify Ubuntu OS
- `ansible_distribution_version`: Used to verify 24.04 LTS
- `ansible_swaptotal_mb`: Used to check if swap is enabled

Dependencies
------------

None. This is a foundational role that runs before other cluster roles.

What This Role Does
-------------------

1. **OS Verification**: Warns if node is not running Ubuntu 24.04 LTS
2. **Package Installation**: Installs required packages:
   - `open-iscsi`: Required for Longhorn distributed storage
   - `curl`: For downloading RKE2 installer
   - `vim`: Text editor for configuration
   - `ca-certificates`: SSL/TLS certificate validation
3. **iSCSI Service**: Enables and starts `iscsid` service for Longhorn
4. **Swap Disable**: Disables swap (required by Kubernetes)
5. **Persistent Swap Removal**: Removes swap entries from `/etc/fstab`

Example Playbook
----------------

```yaml
- hosts: all
  become: yes
  roles:
    - common
```

License
-------

MIT

Author Information
------------------

Part of RKE2 Lab Automation project.
