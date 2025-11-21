# Homelab Kubernetes on Proxmox

Automated POSIX shell scripts to deploy a Kubernetes cluster on Proxmox using Cluster API and Talos Linux.

## Prerequisites

- Linux system (Arch, Debian/Ubuntu, or Alpine)
- Docker installed and running
- Proxmox VE server with SSH access
- Talos ISO uploaded to Proxmox storage

## Scripts Overview

### 0-Homelab.conf
Central configuration file containing all variables. **Edit this first** with your Proxmox settings.

Key settings:
- `PROXMOX_HOST`: Your Proxmox server IP
- `PROXMOX_USER`: API username (just the name, e.g. "capi")
- `PROXMOX_SECRET`: API token secret (generated automatically)

### 1-PreRequisites.sh
Installs Kubernetes tools with user confirmation:
- kubectl (Kubernetes CLI)
- talosctl (Talos Linux CLI)  
- kind (Kubernetes in Docker)
- clusterctl (Cluster API CLI)

Verifies Docker service status across different init systems.

### 2-PrepareProxmox.sh
Prepares Proxmox infrastructure:
- Creates API user and token automatically
- Creates Talos VM template from ISO
- Configures VM template with proper settings

### 3-ClusterAPI.sh
Deploys Kubernetes cluster:
- Sets up Cluster API management cluster
- Deploys Talos Kubernetes cluster on Proxmox

## Quick Start

1. **Download Talos ISO**
   ```bash
   # Visit factory.talos.dev and download with qemu-guest-agent extension
   # Or use direct link:
   wget https://factory.talos.dev/image/b8e8eab508b1cb7bf1607c0666c3d7f319f20d7e3b20badf0a04c3f0a088881a/v1.8.3/metal-amd64.iso
   ```

2. **Upload ISO to Proxmox**
   - Upload the ISO to your Proxmox storage (usually `local` or `Data`)
   - Note the storage name and ISO filename

3. **Configure Settings**
   ```bash
   # Edit configuration with your Proxmox details
   nano 0-Homelab.conf
   ```

4. **Run Scripts in Order**
   ```bash
   ./1-PreRequisites.sh    # Install tools
   ./2-PrepareProxmox.sh   # Prepare Proxmox
   ./3-ClusterAPI.sh       # Deploy cluster
   ```

## Features

- **POSIX Compatible**: Works with sh, bash, ash, dash
- **Multi-Distribution**: Supports Arch, Debian/Ubuntu, Alpine Linux  
- **Automated Setup**: Creates Proxmox users and tokens automatically
- **Centralized Config**: Single configuration file for all scripts
- **User Confirmations**: Interactive prompts for all installations
