# Requirements Document

## Introduction

This document specifies the requirements for an automated MLOps and workflow automation platform deployment system. The system automates the provisioning of a production-ready RKE2 Kubernetes cluster with integrated storage, networking, certificate management, and MLOps applications across five physical servers. The automation uses Ansible to ensure repeatable, idempotent deployments.

## Glossary

- **Automation_System**: The Ansible-based automation that provisions and configures the entire platform
- **RKE2_Cluster**: The Rancher Kubernetes Engine 2 cluster consisting of server and agent nodes
- **Server_Node**: A Kubernetes control plane node running RKE2 server components
- **Agent_Node**: A Kubernetes worker node running RKE2 agent components
- **Longhorn_System**: Distributed block storage system for persistent volumes
- **MetalLB_System**: Bare-metal load balancer providing external IP addresses
- **Ingress_Controller**: RKE2's built-in nginx ingress controller for HTTP/HTTPS routing
- **Cert_Manager**: Automated certificate management system for TLS/SSL certificates
- **MinIO_Service**: S3-compatible object storage service
- **ClearML_Platform**: MLOps platform for experiment tracking and model management
- **N8N_Service**: Workflow automation platform
- **Target_Domain**: The ljf.home domain used for service access
- **IP_Pool**: The 172.16.86.x network range for external service IPs
- **Operator**: The user executing the automation system

## Requirements

### Requirement 1: Automated Cluster Provisioning

**User Story:** As an operator, I want to provision the entire RKE2 cluster automatically, so that I can deploy consistently without manual configuration steps.

#### Acceptance Criteria

1. WHEN the Operator executes the Automation_System, THE Automation_System SHALL install RKE2 server components on three designated Server_Nodes
2. WHEN the Operator executes the Automation_System, THE Automation_System SHALL install RKE2 agent components on two designated Agent_Nodes
3. WHEN installing Server_Nodes, THE Automation_System SHALL configure a High-Availability cluster with three control plane nodes
4. WHEN configuring the RKE2_Cluster, THE Automation_System SHALL disable the default rke2-service-lb component
5. WHEN the RKE2_Cluster is provisioned, THE Automation_System SHALL verify that all nodes join the cluster successfully within 300 seconds

### Requirement 2: Distributed Storage Deployment

**User Story:** As an operator, I want distributed block storage automatically configured, so that applications have persistent storage with data replication.

#### Acceptance Criteria

1. WHEN the RKE2_Cluster is operational, THE Automation_System SHALL deploy the Longhorn_System using Helm charts
2. WHEN deploying the Longhorn_System, THE Automation_System SHALL create the longhorn-system namespace
3. WHEN the Longhorn_System is deployed, THE Automation_System SHALL configure Longhorn as the default StorageClass
4. WHEN applications request persistent storage, THE Longhorn_System SHALL provision PersistentVolumes with replication across Server_Nodes
5. WHEN the Longhorn_System deployment completes, THE Automation_System SHALL wait for all Longhorn components to reach ready state within 600 seconds

### Requirement 3: Load Balancer Configuration

**User Story:** As an operator, I want external IP addresses automatically assigned to services, so that applications are accessible from outside the cluster.

#### Acceptance Criteria

1. WHEN the RKE2_Cluster is operational, THE Automation_System SHALL deploy the MetalLB_System using Helm charts
2. WHEN deploying the MetalLB_System, THE Automation_System SHALL configure kube-proxy with strictARP mode enabled
3. WHEN the MetalLB_System is deployed, THE Automation_System SHALL create an IPAddressPool resource with addresses from the IP_Pool
4. WHEN the MetalLB_System is operational, THE Automation_System SHALL configure Layer 2 advertisement mode
5. WHEN a LoadBalancer service is created, THE MetalLB_System SHALL assign an IP address from the IP_Pool within 30 seconds

### Requirement 4: Ingress Traffic Routing

**User Story:** As an operator, I want HTTP/HTTPS traffic automatically routed to services based on hostnames, so that users can access applications via domain names.

#### Acceptance Criteria

1. WHEN the RKE2_Cluster is provisioned, THE Ingress_Controller SHALL be available using the nginx IngressClass
2. WHEN an Ingress resource is created with a hostname, THE Ingress_Controller SHALL route HTTP traffic to the specified service
3. WHEN an Ingress resource is created with a hostname, THE Ingress_Controller SHALL route HTTPS traffic to the specified service
4. WHEN multiple services use different hostnames, THE Ingress_Controller SHALL route traffic to the correct service based on the Host header
5. WHEN the Ingress_Controller receives a request, THE Ingress_Controller SHALL forward the request to a healthy backend pod within 100 milliseconds

### Requirement 5: Certificate Management

**User Story:** As an operator, I want TLS certificates automatically provisioned and renewed, so that all services have secure HTTPS access without manual certificate management.

#### Acceptance Criteria

1. WHEN the RKE2_Cluster is operational, THE Automation_System SHALL deploy the Cert_Manager using Helm charts with CRDs installed
2. WHEN the Cert_Manager is deployed, THE Automation_System SHALL create a ClusterIssuer resource for Let's Encrypt staging environment
3. WHEN an Ingress resource includes the cert-manager.io/cluster-issuer annotation, THE Cert_Manager SHALL request a TLS certificate from Let's Encrypt
4. WHEN a certificate is requested, THE Cert_Manager SHALL complete the HTTP-01 challenge using the Ingress_Controller
5. WHEN a certificate expires within 30 days, THE Cert_Manager SHALL automatically renew the certificate

### Requirement 6: Object Storage Deployment

**User Story:** As an operator, I want S3-compatible object storage automatically deployed, so that applications can store and retrieve large files and ML artifacts.

#### Acceptance Criteria

1. WHEN the Longhorn_System is operational, THE Automation_System SHALL deploy the MinIO_Service using Helm charts
2. WHEN deploying the MinIO_Service, THE Automation_System SHALL configure persistent storage using the Longhorn_System StorageClass
3. WHEN deploying the MinIO_Service, THE Automation_System SHALL create an Ingress resource with hostname minio.Target_Domain
4. WHEN the MinIO_Service is deployed, THE Automation_System SHALL configure root credentials from inventory variables
5. WHEN the MinIO_Service is operational, THE MinIO_Service SHALL provide S3-compatible API endpoints accessible via HTTPS

### Requirement 7: MLOps Platform Deployment

**User Story:** As an operator, I want the ClearML MLOps platform automatically deployed, so that data scientists can track experiments and manage ML models.

#### Acceptance Criteria

1. WHEN the Longhorn_System is operational, THE Automation_System SHALL deploy the ClearML_Platform using Helm charts
2. WHEN deploying the ClearML_Platform, THE Automation_System SHALL configure persistent storage using the Longhorn_System StorageClass
3. WHEN deploying the ClearML_Platform, THE Automation_System SHALL create Ingress resources for webserver at clearml.Target_Domain
4. WHEN deploying the ClearML_Platform, THE Automation_System SHALL create Ingress resources for apiserver at api.clearml.Target_Domain
5. WHEN deploying the ClearML_Platform, THE Automation_System SHALL create Ingress resources for fileserver at files.clearml.Target_Domain
6. WHEN the ClearML_Platform is operational, THE ClearML_Platform SHALL provide web interface access via HTTPS at clearml.Target_Domain

### Requirement 8: Workflow Automation Deployment

**User Story:** As an operator, I want the n8n workflow automation platform automatically deployed, so that users can create automated workflows connecting ML services.

#### Acceptance Criteria

1. WHEN the Longhorn_System is operational, THE Automation_System SHALL deploy the N8N_Service using Helm charts
2. WHEN deploying the N8N_Service, THE Automation_System SHALL configure persistent storage using the Longhorn_System StorageClass
3. WHEN deploying the N8N_Service, THE Automation_System SHALL create an Ingress resource with hostname n8n.Target_Domain
4. WHEN deploying the N8N_Service, THE Automation_System SHALL configure basic authentication with credentials from inventory variables
5. WHEN the N8N_Service is operational, THE N8N_Service SHALL provide web interface access via HTTPS at n8n.Target_Domain

### Requirement 9: Idempotent Deployment

**User Story:** As an operator, I want to execute the automation multiple times safely, so that I can update configurations or recover from failures without causing errors.

#### Acceptance Criteria

1. WHEN the Operator executes the Automation_System on an existing deployment, THE Automation_System SHALL detect existing resources
2. WHEN existing resources match the desired state, THE Automation_System SHALL report no changes required
3. WHEN existing resources differ from the desired state, THE Automation_System SHALL update only the changed resources
4. WHEN the Operator executes the Automation_System multiple times with identical configuration, THE Automation_System SHALL produce identical cluster states
5. WHEN a deployment task fails, THE Operator SHALL re-execute the Automation_System without requiring manual cleanup

### Requirement 10: Deployment Verification

**User Story:** As an operator, I want the automation to verify successful deployment, so that I can confirm all services are operational before using the platform.

#### Acceptance Criteria

1. WHEN deploying Helm charts, THE Automation_System SHALL wait for all pods to reach ready state before proceeding
2. WHEN a Helm deployment exceeds the configured timeout, THE Automation_System SHALL report a failure with diagnostic information
3. WHEN all deployments complete, THE Automation_System SHALL verify that all expected namespaces exist
4. WHEN all deployments complete, THE Automation_System SHALL verify that all Ingress resources have assigned IP addresses
5. WHEN the Automation_System completes successfully, THE Automation_System SHALL output a summary of deployed services with access URLs

### Requirement 11: Configuration Management

**User Story:** As an operator, I want to configure deployment parameters via inventory files and encrypted secrets, so that I can customize the deployment for different environments without exposing sensitive credentials.

#### Acceptance Criteria

1. WHEN the Operator defines node IP addresses in the inventory file, THE Automation_System SHALL use those addresses for cluster provisioning
2. WHEN the Operator defines the IP_Pool range in the inventory file, THE Automation_System SHALL configure MetalLB_System with that range
3. WHEN the Operator defines the Target_Domain in the inventory file, THE Automation_System SHALL configure all Ingress resources with that domain
4. WHEN the Operator stores service credentials in an Ansible Vault encrypted file, THE Automation_System SHALL decrypt and use those credentials during deployment
5. WHEN the Operator defines ACME email in the inventory file, THE Automation_System SHALL configure Cert_Manager with that email address

### Requirement 12: High Availability

**User Story:** As an operator, I want the cluster to remain operational during single node failures, so that services continue running without interruption.

#### Acceptance Criteria

1. WHEN the RKE2_Cluster has three Server_Nodes, THE RKE2_Cluster SHALL maintain quorum with two operational Server_Nodes
2. WHEN one Server_Node fails, THE RKE2_Cluster SHALL continue accepting API requests
3. WHEN the Longhorn_System has data replicated across nodes, THE Longhorn_System SHALL provide access to data when one node fails
4. WHEN one Agent_Node fails, THE RKE2_Cluster SHALL reschedule pods to operational Agent_Nodes within 60 seconds
5. WHEN a failed node recovers, THE RKE2_Cluster SHALL automatically reintegrate the node without operator intervention
