#!/bin/bash

# Simple cleanup script for Traefik homelab deployment
# Uses the cluster created by 3-DeployCluster.sh

set -e

# Change to parent directory to source config properly
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$(dirname "$SCRIPT_DIR")"

# Source shared configuration
if [ -f "./0-Homelab.conf" ]; then
    . ./0-Homelab.conf
else
    echo "[ERROR] Configuration file 0-Homelab.conf not found!"
    echo "Please ensure 0-Homelab.conf exists in the homelab directory."
    exit 1
fi

# Return to traefik directory
cd "$SCRIPT_DIR"

# Check if kubeconfig exists
KUBECONFIG_FILE="../${KUBECTL_CONFIG_PATH}/${KUBECTL_CONFIG_FILE}"
if [ ! -f "${KUBECONFIG_FILE}" ]; then
    echo "[ERROR] Kubeconfig not found at ${KUBECONFIG_FILE}"
    echo "Please run ../4-GetSecrets.sh first to retrieve the cluster credentials."
    exit 1
fi

echo "Using kubeconfig: ${KUBECONFIG_FILE}"
echo "Cleaning up Traefik deployment..."

# Set kubeconfig for all kubectl commands
export KUBECONFIG="${KUBECONFIG_FILE}"

# Remove ingress routes
kubectl delete -f ingressroutes.yaml --ignore-not-found=true

# Remove whoami app
kubectl delete -f whoami.yaml --ignore-not-found=true

# Remove Traefik
kubectl delete -f traefik.yaml --ignore-not-found=true

# Remove MetalLB configuration
kubectl delete -f metallb.yaml --ignore-not-found=true

# Remove RBAC
kubectl delete -f rbac.yaml --ignore-not-found=true

# Clean up any leftover/duplicate RBAC resources from previous deployments
kubectl delete clusterrole traefik --ignore-not-found=true
kubectl delete clusterrolebinding traefik traefik-traefik-binding --ignore-not-found=true

echo "Cleanup complete!"

echo "Cleanup complete!"
echo "All Traefik resources have been removed from the ${CLUSTER_NAME} cluster."