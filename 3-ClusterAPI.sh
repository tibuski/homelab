#!/bin/sh
# Cluster API configuration for Proxmox and Talos
# POSIX compliant

set -e

# Source shared configuration
if [ -f "./0-Homelab.conf" ]; then
    . ./0-Homelab.conf
else
    printf "\033[0;31m[ERROR]\033[0m Configuration file 0-Homelab.conf not found!\n"
    printf "Please ensure 0-Homelab.conf is in the same directory as this script.\n"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

print_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

print_info "Using configuration from 0-Homelab.conf"
print_info "Management Cluster: ${MANAGEMENT_CLUSTER_NAME}"
print_info "Control Plane Endpoint: ${CONTROL_PLANE_ENDPOINT_IP}"
echo

# Create management cluster
kind create cluster --name "${MANAGEMENT_CLUSTER_NAME}"

# Create talos-builder namespace
kubectl create namespace "${TALOS_NAMESPACE}"

# Create clusterctl configuration directory if it doesn't exist
mkdir -p "$(dirname "${CLUSTERCTL_CONFIG_PATH}")"

# Create clusterctl configuration for Proxmox
cat <<EOF > "${CLUSTERCTL_CONFIG_PATH}"
# Proxmox provider configuration
PROXMOX_URL: "https://${PROXMOX_HOST}:${PROXMOX_PORT}"
PROXMOX_TOKEN: "${PROXMOX_TOKEN}"
PROXMOX_SECRET: "${PROXMOX_SECRET}"

# Image and template settings
PROXMOX_SOURCENODE: "${PROXMOX_SOURCENODE}"
TEMPLATE_VMID: "${TEMPLATE_VMID}"

# Network configuration
CONTROL_PLANE_ENDPOINT_IP: "${CONTROL_PLANE_ENDPOINT_IP}"
GATEWAY: "${GATEWAY}"
IP_PREFIX: "${IP_PREFIX}"
DNS_SERVERS: "${DNS_SERVERS}"
EOF
