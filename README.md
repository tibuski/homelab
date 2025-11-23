# Homelab Kubernetes on Proxmox

Automated POSIX shell scripts to deploy a Kubernetes cluster on Proxmox using Cluster API and Talos Linux.

## Credits

This project was inspired by [Quentin Joly's excellent guide](https://une-tasse-de.cafe/blog/talos-capi-proxmox/) on deploying Talos with Cluster API on Proxmox. His detailed walkthrough provided the foundation for these automation scripts.

## Quick Deploy

Clean setup and deploy cluster:
```bash
./99-CleanAll.sh -f && ./1-PreRequisites.sh && ./2-PrepareProxmox.sh && ./3-DeployCluster.sh
```

Once cluster is ready, retrieve credentials:
```bash
./4-GetSecrets.sh
```

## Prerequisites

- Linux system (Arch, Debian/Ubuntu, or Alpine)
- Docker installed and running
- Proxmox VE server with SSH root access
- Talos nocloud ISO with QEMU guest agent

## Scripts Overview

### 0-Homelab.conf
Central configuration file containing all variables. **Edit this first** with your Proxmox settings.

Key settings:
- `PROXMOX_HOST`: Your Proxmox server IP
- `PROXMOX_USER`: API username (default: "capi")
- `PROXMOX_SECRET`: API token secret (generated automatically)
- `TEMPLATE_VMID`: VM template ID (default: 9000)
- `TEMPLATE_TAG`: VM identification tag for management

### 1-PreRequisites.sh
Installs Kubernetes tools with user confirmation:
- kubectl (Kubernetes CLI)
- talosctl (Talos Linux CLI)  
- kind (Kubernetes in Docker)
- clusterctl (Cluster API CLI)

Features auto-detection of package managers and init systems.

### 2-PrepareProxmox.sh
Proxmox infrastructure setup:
- Creates API user and token with permissions
- Creates VM template from Talos ISO
- Configures CPU security flags (AES, PCID, Spectre mitigations)
- Shows qm commands before execution
- Tags template for identification

### 3-DeployCluster.sh
Deploys Kubernetes cluster:
- Sets up Cluster API management cluster using kind
- Creates Talos Kubernetes cluster on Proxmox VMs
- Configures Virtual IP for control plane
- Applies disk and network patches to nodes
- Monitors cluster readiness

### 4-GetSecrets.sh
Retrieves cluster credentials:
- Extracts kubeconfig from Cluster API secrets
- Extracts talosconfig from Cluster API secrets  
- Tests connectivity to cluster
- Provides usage commands
- Verifies cluster independence from management cluster

### 99-CleanAll.sh
Cleanup utility:
- Removes clusterctl-managed clusters
- Deletes kind clusters
- Removes VMs/templates by tag
- Interactive confirmation or force mode
- Removes unreferenced disks

## Network Configuration

Cluster network settings:
- Control Plane VIP: Uses `CONTROL_PLANE_ENDPOINT_IP` variable
- Node IP Pool: Uses `IP_POOL_START` to `IP_POOL_END` range
- Gateway: Uses `GATEWAY` variable
- DNS: Uses `DNS_SERVERS` variable

## Quick Start

1. **Download Talos ISO**
   
   Download nocloud ISO with QEMU guest agent support:
   [Talos Factory - nocloud with QEMU guest agent](https://factory.talos.dev/?arch=amd64&cmdline-set=true&extensions=-&extensions=siderolabs%2Fqemu-guest-agent&platform=nocloud&target=cloud)

2. **Upload ISO to Proxmox**
   - Upload the ISO to your Proxmox storage
   - Update `TALOS_ISO_PATH` in configuration file

3. **Configure Settings**
   ```bash
   # Copy secrets template and add your API secret
   cp 0-Homelab.secrets.template 0-Homelab.secrets
   nano 0-Homelab.secrets  # Add your PROXMOX_SECRET here
   
   # Edit main configuration with your Proxmox details
   nano 0-Homelab.conf
   ```

4. **Deploy Cluster**
   ```bash
   # Option 1: Quick deploy (clean + setup)
   ./99-CleanAll.sh -f && ./1-PreRequisites.sh && ./2-PrepareProxmox.sh && ./3-DeployCluster.sh
   
   # Option 2: Step by step
   ./1-PreRequisites.sh     # Install tools
   ./2-PrepareProxmox.sh    # Prepare Proxmox infrastructure
   ./3-DeployCluster.sh     # Deploy Kubernetes cluster (wait for completion)
   ```

5. **Retrieve Cluster Credentials (after cluster is ready)**
   ```bash
   ./4-GetSecrets.sh        # Get kubeconfig and talosconfig
   ```

6. **Deploy Load Balancer (optional)**
   ```bash
   cd traefik/
   ./deploy.sh              # Deploy Traefik ingress controller
   ```

7. **Cleanup Operations**
   ```bash
   ./99-CleanAll.sh           # Interactive cleanup (all resources)
   ./99-CleanAll.sh -f        # Automated cleanup (all resources)
   ```

## Components

### Core Cluster
- **Talos Linux**: Immutable Kubernetes OS
- **Cluster API**: Declarative cluster lifecycle management
- **MetalLB**: Load balancer for bare metal environments

### Load Balancer (Optional)
- **Traefik**: HTTP reverse proxy and load balancer
- **IngressRoute**: Custom routing configuration
- **Dashboard**: Web UI for traffic monitoring

## Features

- **POSIX Compatible**: Works with sh, bash, ash, dash shells
- **Multi-Distribution**: Supports Arch, Debian/Ubuntu, Alpine Linux  
- **Automated Setup**: Creates Proxmox users, tokens, and templates
- **Security Focused**: Enhanced CPU security flags and proper permissions
- **Centralized Config**: Single configuration file with tag-based management
- **High Availability**: VIP configuration for control plane endpoint stability
- **Advanced Networking**: Strategic patches for network and disk configuration
- **Smart Monitoring**: Service-based monitoring for better cluster readiness detection
- **User-Friendly**: Command previews and interactive confirmations
- **Comprehensive Cleanup**: Complete environment reset including clusters and VMs
- **One-Command Deploy**: Quick setup with automated cleanup and deployment

## Usage Patterns

### Fresh Installation
```bash
# Setup secrets and configuration first
cp 0-Homelab.secrets.template 0-Homelab.secrets
nano 0-Homelab.secrets  # Add your PROXMOX_SECRET
nano 0-Homelab.conf     # Edit other settings

# Deploy cluster infrastructure
./99-CleanAll.sh -f && ./1-PreRequisites.sh && ./2-PrepareProxmox.sh && ./3-DeployCluster.sh

# Wait for cluster to be ready, then get credentials
./4-GetSecrets.sh
```

### Development Cycle
```bash
# Reset environment
./99-CleanAll.sh

# Redeploy cluster
./3-DeployCluster.sh

# Once ready, get credentials
./4-GetSecrets.sh
```

### Cleanup Only
```bash
# Remove all clusters and VMs
./99-CleanAll.sh -f
```
