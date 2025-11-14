# RKE2 Lab Automation

Automated deployment of a production-ready MLOps and workflow automation platform on a 5-node RKE2 Kubernetes cluster.

## Overview

This project automates the deployment of:

- **RKE2 Kubernetes Cluster**: High-availability 3-server + 2-agent configuration
- **Infrastructure Services**: Longhorn storage, MetalLB load balancer, cert-manager
- **MLOps Platform**: ClearML for experiment tracking and model management
- **Object Storage**: MinIO S3-compatible storage for ML artifacts
- **Workflow Automation**: n8n for orchestrating ML pipelines

All services are accessible via HTTPS with automatic TLS certificate provisioning through Let's Encrypt.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    5-Node RKE2 Cluster                       │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│  │ Node-1   │  │ Node-2   │  │ Node-3   │                 │
│  │ (Server) │  │ (Server) │  │ (Server) │                 │
│  │ RKE2 HA  │  │ RKE2 HA  │  │ RKE2 HA  │                 │
│  └──────────┘  └──────────┘  └──────────┘                 │
│                                                              │
│  ┌──────────┐  ┌──────────┐                                │
│  │ Node-4   │  │ Node-5   │                                │
│  │ (Agent)  │  │ (Agent)  │                                │
│  └──────────┘  └──────────┘                                │
│                                                              │
│  Infrastructure: Longhorn | MetalLB | cert-manager          │
│  Applications: MinIO | ClearML | n8n                        │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- **Control Machine**: Python 3.12+, Ansible 10.0.0+
- **Target Nodes**: 5 nodes running Ubuntu 24.04 LTS
  - 3 server nodes: 8 GB RAM, 4 CPU cores, 100 GB disk
  - 2 agent nodes: 8 GB RAM, 4 CPU cores, 100 GB disk
- **Network**: Static IPs, reserved MetalLB IP range

### Installation

```bash
# 1. Install dependencies
curl -LsSf https://astral.sh/uv/install.sh | sh
uv sync
ansible-galaxy install -r requirements.yml

# 2. Configure inventory
# Edit inventory.yml with your node IPs and settings

# 3. Configure secrets
cat > vars/secrets.yml << EOF
vault_minio_root_pass: "your-secure-password"
vault_n8n_admin_pass: "your-secure-password"
EOF
ansible-vault encrypt vars/secrets.yml

# 4. Test connectivity
ansible all -m ping

# 5. Deploy
ansible-playbook playbook.yml --ask-vault-pass
```

**Deployment Time**: ~30-45 minutes

## Documentation

### Getting Started

- **[Quick Start Guide](docs/QUICKSTART.md)** - Get up and running in 30 minutes
- **[Configuration Guide](docs/CONFIGURATION.md)** - Detailed configuration options
- **[Architecture Guide](docs/ARCHITECTURE.md)** - System architecture and design

### Operations

- **[Verification Guide](docs/VERIFICATION.md)** - Verify deployment health
- **[Service Access Guide](docs/SERVICE-ACCESS.md)** - Configure DNS and access services
- **[Testing Guide](docs/TESTING.md)** - Testing and validation procedures
- **[Maintenance Guide](docs/MAINTENANCE.md)** - Upgrades, backups, and maintenance
- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** - Common issues and solutions

## Service URLs

After deployment and DNS configuration:

- **MinIO**: <https://minio.ljf.home> (Object Storage)
- **ClearML**: <https://clearml.ljf.home> (MLOps Platform)
- **n8n**: <https://n8n.ljf.home> (Workflow Automation)

See [Service Access Guide](docs/SERVICE-ACCESS.md) for credentials and setup.

## Project Structure

```
k8s-lab/
├── docs/                      # Documentation
│   ├── QUICKSTART.md          # Quick start guide
│   ├── CONFIGURATION.md       # Configuration reference
│   ├── ARCHITECTURE.md        # Architecture documentation
│   ├── VERIFICATION.md        # Verification procedures
│   ├── SERVICE-ACCESS.md      # Service access setup
│   ├── TESTING.md             # Testing guide
│   ├── MAINTENANCE.md         # Maintenance operations
│   └── TROUBLESHOOTING.md     # Troubleshooting guide
├── scripts/                   # Validation scripts
│   ├── pre-deployment-test.sh
│   ├── post-deployment-validation.sh
│   └── service-accessibility-test.sh
├── roles/                     # Ansible roles
│   ├── common/                # Node prerequisites
│   └── k8s_apps/              # Kubernetes applications
├── inventory.yml              # Node definitions
├── playbook.yml               # Main playbook
├── ansible.cfg                # Ansible configuration
├── requirements.yml           # Ansible dependencies
├── vars/secrets.yml           # Encrypted credentials
└── README.md                  # This file
```

## Verification

After deployment, verify the cluster:

```bash
# Run automated validation
./scripts/post-deployment-validation.sh

# Check cluster status
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get nodes
kubectl get pods -A

# Test service accessibility
./scripts/service-accessibility-test.sh
```

See [Verification Guide](docs/VERIFICATION.md) for detailed checks.

## Maintenance

Common maintenance operations:

```bash
# Add a node
# Edit inventory.yml, then:
ansible-playbook playbook.yml --limit new-node --ask-vault-pass

# Upgrade RKE2
# Edit rke2_version in inventory.yml, then:
ansible-playbook playbook.yml --limit rke2_servers --ask-vault-pass
ansible-playbook playbook.yml --limit rke2_agents --ask-vault-pass

# Update application versions
# Edit roles/k8s_apps/defaults/main.yml, then:
ansible-playbook playbook.yml --tags applications --ask-vault-pass
```

See [Maintenance Guide](docs/MAINTENANCE.md) for detailed procedures.

## Troubleshooting

If you encounter issues:

1. Check the [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
2. Run validation scripts: `./scripts/post-deployment-validation.sh`
3. Check logs: `kubectl logs -n <namespace> <pod-name>`
4. Review events: `kubectl get events -A --sort-by='.lastTimestamp'`

## Implementation Status

### Completed

- ✅ Ansible project structure and configuration
- ✅ Inventory template with 5-node structure
- ✅ Common role for node prerequisites
- ✅ Main playbook orchestration
- ✅ RKE2 HA cluster deployment (via lablabs.rke2)
- ✅ Secrets management with Ansible Vault
- ✅ Infrastructure services (Longhorn, MetalLB, cert-manager)
- ✅ Application services (MinIO, ClearML, n8n)
- ✅ Comprehensive documentation
- ✅ Testing and validation scripts

### In Progress

- ⚠️ Production certificate configuration
- ⚠️ Advanced monitoring setup

See `.kiro/specs/rke2-lab-automation/tasks.md` for detailed implementation plan.

## Contributing

This is a lab automation project. Contributions welcome via pull requests.

## License

MIT-0

## References

- [RKE2 Documentation](https://docs.rke2.io/)
- [Ansible Documentation](https://docs.ansible.com/)
- [Longhorn Documentation](https://longhorn.io/docs/)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [MinIO Documentation](https://min.io/docs/)
- [ClearML Documentation](https://clear.ml/docs/)
- [n8n Documentation](https://docs.n8n.io/)

## Support

For issues and questions:

1. Check the [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
2. Review [Testing Guide](docs/TESTING.md) for validation procedures
3. Check Ansible logs: `ansible-playbook playbook.yml -vvv`
4. Review Kubernetes events: `kubectl get events -A --sort-by='.lastTimestamp'`
