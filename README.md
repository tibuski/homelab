# Homelab K8s Environment

Automated scripts to build a Kubernetes cluster on Proxmox using Cluster API and Talos.

## Scripts

### 0-Homelab.conf
Configuration file with all variables. Edit this first.

### 1-PreRequisites.sh
Installs tools: kubectl, talosctl, kind, clusterctl. Checks Docker status.

**Supported OS:** Arch Linux, Debian/Ubuntu, Alpine Linux

```bash
./1-PreRequisites.sh
```

### 2-PrepareProxmox.sh
Creates Talos VM template on Proxmox server.

**Prerequisites:** 
- Download Talos ISO from [factory.talos.dev](https://factory.talos.dev/?arch=amd64&cmdline-set=true&extensions=-&extensions=siderolabs%2Fqemu-guest-agent&platform=metal&target=metal)
- Upload ISO to Proxmox storage
- SSH key access to Proxmox root

```bash
./2-PrepareProxmox.sh
```

### 3-ClusterAPI.sh
Sets up Cluster API management cluster and deploys Talos Kubernetes cluster.

```bash
./3-ClusterAPI.sh
```

## Quick Start

1. Edit `0-Homelab.conf` with your settings
2. Run scripts in order: `./1-PreRequisites.sh && ./2-PrepareProxmox.sh && ./3-ClusterAPI.sh`

## Requirements

- Linux (Arch/Debian/Alpine)
- sudo access
- Docker
- Proxmox server with SSH access
