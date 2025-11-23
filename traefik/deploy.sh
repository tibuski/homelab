#!/bin/bash

# Simple Traefik deployment script for homelab
# No RBAC, no Prometheus metrics - just the essentials
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
echo "Deploying simple Traefik setup for homelab..."

# Set kubeconfig for all kubectl commands
export KUBECONFIG="${KUBECONFIG_FILE}"

# Create namespace
kubectl create namespace traefik --dry-run=client -o yaml | kubectl apply -f -

# Deploy RBAC (required for Traefik to discover Kubernetes resources)
kubectl apply -f rbac.yaml

# Deploy Traefik
kubectl apply -f traefik.yaml

# Deploy MetalLB configuration
kubectl apply -f metallb.yaml

# Deploy whoami app
kubectl apply -f whoami.yaml

# Deploy ingress routes
kubectl apply -f ingressroutes.yaml

echo "Deployment complete!"
echo ""
echo "Services will be available at:"
echo "- Traefik Dashboard: http://dashboard.k8s.brichet.be (on 192.168.25.105:80)"
echo "- Whoami App: http://whoami.k8s.brichet.be (on 192.168.25.105:80)"
echo ""
echo "Make sure your DNS or /etc/hosts file points:"
echo "192.168.25.105 dashboard.k8s.brichet.be whoami.k8s.brichet.be"
echo ""
echo "To check status:"
echo "kubectl --kubeconfig=\"${KUBECONFIG_FILE}\" get pods -n traefik"