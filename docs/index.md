---
layout: default
title: Home
---

# RKE2 Lab Automation Documentation

Welcome to the comprehensive documentation for RKE2 Lab Automation - an automated deployment solution for production-ready MLOps platforms on RKE2 Kubernetes.

## Quick Links

### Getting Started

- **[Quick Start Guide](QUICKSTART.md)** - Get your cluster running in 30-45 minutes
- **[Architecture Overview](ARCHITECTURE.md)** - Understand the system design
- **[Configuration Guide](CONFIGURATION.md)** - Detailed configuration options

### Operations

- **[Verification Guide](VERIFICATION.md)** - Verify deployment health
- **[Service Access Guide](SERVICE-ACCESS.md)** - Configure DNS and access services
- **[Testing Guide](TESTING.md)** - Testing and validation procedures
- **[Maintenance Guide](MAINTENANCE.md)** - Upgrades, backups, and maintenance
- **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Common issues and solutions

## What's Included

This automation deploys a complete 5-node RKE2 cluster with:

### Infrastructure Services

- **Longhorn** - Distributed block storage with replication
- **MetalLB** - Bare-metal load balancer (Layer 2 mode)
- **cert-manager** - Automated TLS certificate management

### Application Services

- **MinIO** - S3-compatible object storage (50 GB)
- **ClearML** - MLOps platform for experiment tracking
- **n8n** - Workflow automation platform (5 GB)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    5-Node RKE2 Cluster                       │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│  │ opt1   │  │ opt2   │  │ opt3   │                 │
│  │ (Server) │  │ (Server) │  │ (Server) │                 │
│  │ RKE2 HA  │  │ RKE2 HA  │  │ RKE2 HA  │                 │
│  └──────────┘  └──────────┘  └──────────┘                 │
│                                                              │
│  ┌──────────┐  ┌──────────┐                                │
│  │ opt4   │  │ opt5   │                                │
│  │ (Agent)  │  │ (Agent)  │                                │
│  └──────────┘  └──────────┘                                │
│                                                              │
│  Infrastructure: Longhorn | MetalLB | cert-manager          │
│  Applications: MinIO | ClearML | n8n                        │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- **Control Machine**: Python 3.12+, Ansible 10.0.0+
- **Target Nodes**: 5 Ubuntu 24.04 LTS nodes
  - 3 server nodes: 8 GB RAM, 4 CPU cores, 100 GB disk
  - 2 agent nodes: 8 GB RAM, 4 CPU cores, 100 GB disk
- **Network**: Static IPs, reserved MetalLB IP range

## Quick Installation

```bash
# 1. Install dependencies
curl -LsSf https://astral.sh/uv/install.sh | sh
uv sync
ansible-galaxy install -r requirements.yml

# 2. Configure inventory.yml with your node IPs

# 3. Configure secrets
cat > vars/secrets.yml << EOF
vault_minio_root_pass: "your-secure-password"
vault_n8n_admin_pass: "your-secure-password"
EOF
ansible-vault encrypt vars/secrets.yml

# 4. Deploy
ansible-playbook playbook.yml --ask-vault-pass
```

## Service URLs

After deployment and DNS configuration:

- **MinIO**: <https://minio.ljf.home>
- **ClearML**: <https://clearml.ljf.home>
- **n8n**: <https://n8n.ljf.home>

## Support

- **GitHub Repository**: [View on GitHub](https://github.com/YOUR_USERNAME/k8s-lab)
- **Issues**: Report issues on GitHub
- **Documentation**: You're reading it!

## License

MIT-0

---

**Ready to get started?** Head over to the [Quick Start Guide](QUICKSTART.md)!
