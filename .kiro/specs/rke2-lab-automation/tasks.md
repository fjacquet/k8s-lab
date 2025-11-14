# Implementation Plan

- [x] 1. Set up Ansible project structure and configuration
  - Create ansible.cfg with default settings for SSH, privilege escalation, and fact caching
  - Create inventory.yml template with 5-node structure (3 servers + 2 agents)
  - Create requirements.yml for external dependencies (lablabs.rke2, kubernetes.core collection)
  - Create vars/secrets.yml template for encrypted credentials (MinIO, n8n passwords)
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

- [x] 2. Create common role for node prerequisites
  - Create roles/common/tasks/main.yml with package installation tasks
  - Install required packages: open-iscsi, curl, vim, ca-certificates
  - Enable and start iscsid service for Longhorn storage support
  - Disable swap immediately and remove from fstab
  - Add Ubuntu 24.04 LTS version verification check
  - _Requirements: 1.1, 1.2, 2.4, 12.1_

- [x] 3. Create main playbook orchestration
  - Create playbook.yml with sequential play execution
  - Define play for common role on all nodes
  - Define play for lablabs.rke2 role on all nodes (HA cluster setup)
  - Define play for k8s_apps role infrastructure phase on first server node
  - Define play for k8s_apps role applications phase on first server node
  - _Requirements: 1.1, 1.2, 1.3, 9.1, 9.2, 9.3_

- [x] 4. Create k8s_apps role for infrastructure services
  - Create roles/k8s_apps/tasks/main.yml with phase-based deployment logic
  - Add Kubernetes API readiness check with 300 second timeout
  - Implement kube-proxy strictARP patch for MetalLB Layer 2 mode
  - Deploy Longhorn using Helm with 10-minute wait timeout
  - Deploy MetalLB using Helm with 5-minute wait timeout
  - Create MetalLB IPAddressPool resource with IP range from inventory
  - Create MetalLB L2Advertisement resource for Layer 2 mode
  - Deploy cert-manager using Helm with CRDs installation
  - Create Let's Encrypt staging ClusterIssuer with HTTP-01 solver
  - _Requirements: 2.1, 2.2, 2.3, 2.5, 3.1, 3.2, 3.3, 3.4, 5.1, 5.2, 5.4_

- [x] 5. Create k8s_apps role for application services
  - Deploy MinIO using Helm with Longhorn storage class
  - Configure MinIO with ClusterIP service and nginx ingress
  - Create MinIO ingress resource with cert-manager annotation
  - Deploy ClearML using Helm with Longhorn storage class
  - Create ClearML webserver ingress at clearml.domain
  - Create ClearML apiserver ingress at api.clearml.domain
  - Create ClearML fileserver ingress at files.clearml.domain
  - Deploy n8n using Helm with Longhorn storage class and basic auth
  - Create n8n ingress resource with cert-manager annotation
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 6. Implement deployment verification and error handling
  - Add wait conditions for all Helm deployments with appropriate timeouts
  - Implement MetalLB controller readiness check before creating IPAddressPool
  - Add error handling for Helm deployment failures with diagnostic output
  - Verify all pods reach ready state before proceeding to next phase
  - Add verification tasks for namespace existence after deployments
  - Add verification tasks for ingress IP address assignment
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [x] 7. Create documentation and deployment guide
  - Create README.md with project overview and architecture description
  - Document inventory.yml configuration with all required variables
  - Document Ansible Vault setup for secrets encryption
  - Document deployment workflow from initial setup to service access
  - Document DNS/hosts file configuration for service access
  - Document verification commands for cluster and service status
  - Document maintenance operations (add node, upgrade, update credentials)
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

- [x] 8. Create testing and validation scripts
  - Create pre-deployment connectivity test script
  - Create post-deployment cluster validation script
  - Create service accessibility test script
  - Create idempotency test procedure documentation
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 10.1, 10.2, 10.3, 10.4, 10.5_
