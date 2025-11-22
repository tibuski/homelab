# Homelab Kubernetes on Proxmox

Automated POSIX shell scripts to deploy a Kubernetes cluster on Proxmox using Cluster API and Talos Linux.

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
Comprehensive Proxmox infrastructure setup:
- **Automated User Management**: Creates API user and token with proper permissions
- **VM Template Creation**: Creates optimized Talos template with CPU flags
- **Security Enhanced**: Configures CPU security flags (AES, PCID, Spectre mitigations)
- **Command Logging**: Shows exact qm commands before execution
- **Template Tagging**: Adds management tags for easy identification

### 3-ClusterAPI.sh
Deploys Kubernetes cluster:
- Sets up Cluster API management cluster
- Deploys Talos Kubernetes cluster on Proxmox

### 99-CleanProxmox.sh
Cleanup utility for Proxmox resources:
- **Smart Detection**: Finds VMs/templates by configured tag
- **Safe Cleanup**: Interactive confirmation with force mode support
- **Complete Removal**: Purges from job configurations and destroys unreferenced disks
- **Batch Operations**: Handles multiple resources efficiently

## Quick Start

1. **Download Talos ISO**
   ```bash
   # Download nocloud ISO with QEMU guest agent support
   wget "https://factory.talos.dev/?arch=amd64&cmdline-set=true&extensions=-&extensions=siderolabs%2Fqemu-guest-agent&platform=nocloud&target=cloud"
   ```

2. **Upload ISO to Proxmox**
   - Upload the ISO to your Proxmox storage
   - Update `TALOS_ISO_PATH` in configuration file

3. **Configure Settings**
   ```bash
   # Edit configuration with your Proxmox details
   nano 0-Homelab.conf
   ```

4. **Run Scripts in Order**
   ```bash
   ./1-PreRequisites.sh    # Install tools
   ./2-PrepareProxmox.sh   # Prepare Proxmox infrastructure
   ./3-ClusterAPI.sh       # Deploy Kubernetes cluster
   ```

5. **Cleanup (Optional)**
   ```bash
   ./99-CleanProxmox.sh           # Interactive cleanup
   ./99-CleanProxmox.sh --force   # Automated cleanup
   ```

## Features

- **POSIX Compatible**: Works with sh, bash, ash, dash
- **Multi-Distribution**: Supports Arch, Debian/Ubuntu, Alpine Linux  
- **Automated Setup**: Creates Proxmox users, tokens, and templates
- **Security Focused**: Enhanced CPU security flags and proper permissions
- **Centralized Config**: Single configuration file with tag-based management
- **User-Friendly**: Command previews and interactive confirmations
- **Professional Cleanup**: Safe resource management with batch operations
