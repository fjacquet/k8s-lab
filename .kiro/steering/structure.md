# Project Structure

## Directory Layout

```
k8s-lab/
├── .git/                      # Git repository
├── .kiro/                     # Kiro AI assistant configuration
│   └── steering/              # AI steering rules
├── .venv/                     # Python virtual environment
├── inventory.yml              # Ansible inventory (node definitions)
├── ansible.cfg                # Ansible configuration
├── playbook.yml               # Main Ansible playbook
├── roles/                     # Ansible roles
│   ├── common/                # Common tasks for all nodes
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   └── handlers/
│   ├── rke2_server/           # RKE2 server node setup
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   └── handlers/
│   ├── rke2_agent/            # RKE2 agent nodes setup
│   │   ├── tasks/
│   │   │   └── main.yml
│   │   └── handlers/
│   └── k8s_apps/              # Kubernetes applications (Helm)
│       ├── tasks/
│       │   └── main.yml
│       └── handlers/
├── templates/                 # Jinja2 templates
│   ├── rke2_server_config.yaml.j2
│   ├── rke2_agent_config.yaml.j2
│   └── metallb_config.yaml.j2
├── main.py                    # Python entry point (minimal)
├── pyproject.toml             # Python project configuration
├── uv.lock                    # Dependency lock file
├── .python-version            # Python version specification
├── .gitignore                 # Git ignore rules
├── README.md                  # Project documentation
└── idea.md                    # Project specification

```

## Key Files

### Ansible Configuration

- **inventory.yml**: Defines the 3 nodes (1 server, 2 agents) with IP addresses and groups
- **ansible.cfg**: Sets default user, SSH key, and Ansible behavior
- **playbook.yml**: Orchestrates role execution in correct order

### Roles

Each role follows standard Ansible structure:
- `tasks/main.yml`: Main task list
- `handlers/main.yml`: Event handlers (service restarts, etc.)
- `templates/`: Jinja2 templates for configuration files
- `defaults/main.yml`: Default variables (optional)
- `vars/main.yml`: Role-specific variables (optional)

### Templates

- **rke2_server_config.yaml.j2**: RKE2 server configuration (disables default service-lb)
- **rke2_agent_config.yaml.j2**: RKE2 agent configuration (server URL, token)
- **metallb_config.yaml.j2**: MetalLB IPAddressPool configuration

## Execution Flow

1. **common** role: Runs on all nodes (prerequisites, packages, services)
2. **rke2_server** role: Installs and configures RKE2 server node
3. **rke2_agent** role: Installs and configures RKE2 agent nodes
4. **k8s_apps** role: Deploys Helm charts (Longhorn, MetalLB)

## Configuration Management

- **Inventory variables**: Node IPs, MetalLB IP range
- **Host variables**: Node-specific settings (hostvars)
- **Group variables**: Shared settings across node groups
- **Template variables**: Dynamic configuration via Jinja2

## Conventions

- Use `become: yes` for privilege escalation
- Register important outputs (tokens, kubeconfig) as variables
- Use `wait_for` module to ensure services are ready before proceeding
- Delegate Kubernetes tasks to server node or localhost with kubeconfig
- Use `kubernetes.core.k8s` and `kubernetes.core.helm` modules for K8s operations
