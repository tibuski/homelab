# Homelab K8s Environment

Automated scripts to build a complete Kubernetes environment on Proxmox using Cluster API.

## Overview

This repository contains a series of scripts designed to set up a production-ready Kubernetes cluster from scratch on Proxmox infrastructure using Cluster API. The scripts are numbered in execution order.

## 1-PreRequisites.sh

The first script in the series that installs essential tools and verifies Docker status.

### What it does:
- **Installs kubectl** - Kubernetes command-line tool
- **Installs talosctl** - Talos Linux management tool  
- **Installs kind** - Kubernetes in Docker (for local development)
- **Installs clusterctl** - Cluster API management tool
- **Checks Docker status** - Verifies installation and starts service if needed

### Supported Distributions:
- Arch Linux (including Manjaro)
- Debian (including Ubuntu)
- Alpine Linux
