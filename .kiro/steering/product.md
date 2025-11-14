# Product Overview

## RKE2 Lab Automation

This project automates the provisioning of a production-ready 3-node RKE2 (Rancher Kubernetes Engine 2) cluster using Ansible. It provides a complete infrastructure setup including:

- **RKE2 Cluster**: 1 server node + 2 agent nodes
- **Persistent Storage**: Longhorn for distributed block storage
- **Load Balancing**: MetalLB for bare-metal LoadBalancer services

## Purpose

Designed for lab environments and learning, this automation eliminates manual setup steps and ensures consistent, repeatable cluster deployments. The project follows Kubernetes and RKE2 best practices with security and compliance in mind.

## Target Users

- DevOps engineers learning Kubernetes
- System administrators setting up lab environments
- Teams needing reproducible RKE2 cluster deployments
