# Technology Stack

## Core Technologies

- **Python**: 3.12+
- **Ansible**: 3.4.0+ (ansible-core 2.20.0+)
- **RKE2**: Kubernetes distribution (installed via automation)
- **Longhorn**: Cloud-native distributed block storage
- **MetalLB**: Bare-metal load balancer

## Build System

- **Package Manager**: uv (Python package manager)
- **Dependency Management**: pyproject.toml
- **Virtual Environment**: .venv (managed by uv)

## Project Dependencies

```toml
ansible>=3.4.0
ansible-core>=2.20.0
```

## Common Commands

### Environment Setup

```bash
# Install dependencies
uv sync

# Activate virtual environment
source .venv/bin/activate
```

### Running the Automation

```bash
# Run the main playbook
ansible-playbook playbook.yml

# Run with specific inventory
ansible-playbook -i inventory.yml playbook.yml

# Check mode (dry run)
ansible-playbook playbook.yml --check

# Run specific role/tag
ansible-playbook playbook.yml --tags "common"
```

### Testing and Validation

```bash
# Syntax check
ansible-playbook playbook.yml --syntax-check

# Lint playbooks
ansible-lint playbook.yml

# Test connectivity
ansible all -m ping
```

## Ansible Collections Required

- `kubernetes.core`: For Kubernetes resource management
- `community.general`: For general utilities

Install with:
```bash
ansible-galaxy collection install kubernetes.core
ansible-galaxy collection install community.general
```
