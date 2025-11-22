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

print_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

print_info "Using configuration from 0-Homelab.conf"
print_info "Management Cluster: ${MANAGEMENT_CLUSTER_NAME}"
print_info "Control Plane Endpoint: ${CONTROL_PLANE_ENDPOINT_IP}"
echo

# ===============================================================================
# VM TEMPLATE CREATION ON PROXMOX
# ===============================================================================

# Create temporary local management cluster
if ! kind get clusters | grep -q "^${MANAGEMENT_CLUSTER_NAME}$"; then
    print_info "Creating kind management cluster: ${MANAGEMENT_CLUSTER_NAME}"
    kind create cluster --name "${MANAGEMENT_CLUSTER_NAME}"
    kubectl cluster-info --context kind-management
else
    print_info "Kind cluster '${MANAGEMENT_CLUSTER_NAME}' already exists, skipping creation"
    kubectl cluster-info --context kind-management
fi

# Create clusterctl configuration directory if it doesn't exist
print_info "Creating clusterctl configuration directory: "${CLUSTERCTL_CONFIG_PATH}""
mkdir -p "${CLUSTERCTL_CONFIG_PATH}"

# Create CAPI configuration for Proxmox Provider
print_info "Creating Talos cluster configuration: "${CLUSTERCTL_CONFIG_PATH}/${CLUSTERCTL_CONFIG_FILE}""

cat <<EOF > "${CLUSTERCTL_CONFIG_PATH}/${CLUSTERCTL_CONFIG_FILE}"
# Providers
providers:
  - name: "talos"
    url: "${TALOS_BOOTSTRAP_PROVIDER_URL}"
    type: "BootstrapProvider"
  - name: "talos"
    url: "${TALOS_CONTROL_PLANE_PROVIDER_URL}"
    type: "ControlPlaneProvider"
  - name: "proxmox"
    url: "${PROXMOX_INFRASTRUCTURE_PROVIDER_URL}"
    type: "InfrastructureProvider"

# Proxmox provider configuration
PROXMOX_URL: "https://${PROXMOX_HOST}:${PROXMOX_PORT}"
PROXMOX_TOKEN: "${PROXMOX_TOKEN}"
PROXMOX_SECRET: "${PROXMOX_SECRET}"
CLUSTERCTL_LOG_LEVEL: "4"
EOF


# Create kubectl configurations directory
print_info "Creating kubectl configuration directory: "${CLUSTERCTL_CONFIG_PATH}""
mkdir -p "${KUBECTL_CONFIG_PATH}"

# Note: Proxmox provider handles IP allocation through ProxmoxCluster spec
# No separate IP pool resource needed

# Create Talos cluster YAML configuration
print_info "Creating Talos cluster configuration: "${KUBECTL_CONFIG_PATH}/${KUBECTL_CONFIG_FILE}"
"
cat <<EOF > "${KUBECTL_CONFIG_PATH}/${KUBECTL_CONFIG_FILE}"
---
apiVersion: cluster.x-k8s.io/v1beta2
kind: Cluster
metadata:
  name: ${CLUSTER_NAME}
  namespace: ${CLUSTER_NAMESPACE}
spec:
  clusterNetwork:
    pods:
      cidrBlocks:
        - ${POD_CIDR}
    services:
      cidrBlocks:
        - ${SERVICE_CIDR}
  controlPlaneRef:
    apiGroup: controlplane.cluster.x-k8s.io
    kind: TalosControlPlane
    name: talos-control-plane
  infrastructureRef:
    apiGroup: infrastructure.cluster.x-k8s.io
    kind: ProxmoxCluster
    name: ${PROXMOX_CLUSTER_NAME}
---
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
kind: ProxmoxCluster
metadata:
  name: ${PROXMOX_CLUSTER_NAME}
  namespace: ${CLUSTER_NAMESPACE}
spec:
  controlPlaneEndpoint:
    host: ${CONTROL_PLANE_ENDPOINT_IP}
    port: 6443
  allowedNodes:
    - ${PROXMOX_SOURCENODE}
  ipv4Config:
    addresses:
      - ${IP_POOL_START}-${IP_POOL_END}
    prefix: ${IP_PREFIX}
    gateway: ${GATEWAY}
  dnsServers:
    - ${DNS_SERVERS}
---
apiVersion: controlplane.cluster.x-k8s.io/v1alpha3
kind: TalosControlPlane
metadata:
  name: talos-control-plane
spec:
  version: ${KUBERNETES_VERSION}
  replicas: ${CONTROL_PLANE_REPLICAS}
  infrastructureTemplate:
    kind: ProxmoxMachineTemplate
    apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
    name: control-plane-template
    namespace: ${CLUSTER_NAMESPACE}
  controlPlaneConfig:
    controlplane:
      generateType: controlplane
---
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
kind: ProxmoxMachineTemplate
metadata:
  name: control-plane-template
  namespace: ${CLUSTER_NAMESPACE}
spec:
  template:
    spec:
      disks:
        bootVolume:
          disk: ${TEMPLATE_DISK}
          sizeGb: ${TEMPLATE_DISK_SIZE}
      format: qcow2
      full: true
      memoryMiB: ${TEMPLATE_MEMORY}
      network:
        default:
          bridge: vmbr0
          model: virtio
      numCores: ${TEMPLATE_CORES}
      numSockets: ${TEMPLATE_SOCKETS} 
      sourceNode: ${PROXMOX_SOURCENODE}
      templateID: ${TEMPLATE_VMID}
      checks:
          skipCloudInitStatus: true
          skipQemuGuestAgent: true
      metadataSettings:
          providerIDInjection: true
      
---
apiVersion: cluster.x-k8s.io/v1beta2
kind: MachineDeployment
metadata:
  name: ${CLUSTER_NAME}-workers
  namespace: ${CLUSTER_NAMESPACE}
spec:
  clusterName: ${CLUSTER_NAME}
  replicas: ${WORKER_REPLICAS}
  selector:
    matchLabels:
      cluster.x-k8s.io/deployment-name: ${CLUSTER_NAME}-workers
  template:
    metadata:
      labels:
        cluster.x-k8s.io/deployment-name: ${CLUSTER_NAME}-workers
    spec:
      clusterName: ${CLUSTER_NAME}
      version: ${KUBERNETES_VERSION}
      bootstrap:
        configRef:
          apiGroup: bootstrap.cluster.x-k8s.io
          kind: TalosConfigTemplate
          name: ${CLUSTER_NAME}-workers
      infrastructureRef:
        apiGroup: infrastructure.cluster.x-k8s.io
        kind: ProxmoxMachineTemplate
        name: ${CLUSTER_NAME}-workers
---
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
kind: ProxmoxMachineTemplate
metadata:
  name: ${CLUSTER_NAME}-workers
  namespace: ${CLUSTER_NAMESPACE}
spec:
  template:
    spec:
      sourceNode: ${PROXMOX_SOURCENODE}
      templateID: ${TEMPLATE_VMID}
      format: qcow2
      full: true
      numCores: ${TEMPLATE_CORES}
      memoryMiB: ${TEMPLATE_MEMORY}
      disks:
        bootVolume:
          disk: ${PROXMOX_SOURCENODE}:${TEMPLATE_VMID}
          sizeGb: ${TEMPLATE_DISK_SIZE}
      network:
        default:
          bridge: vmbr0
          model: virtio
---
apiVersion: bootstrap.cluster.x-k8s.io/v1alpha3
kind: TalosConfigTemplate
metadata:
  name: ${CLUSTER_NAME}-workers
  namespace: ${CLUSTER_NAMESPACE}
spec:
  template:
    spec:
      generateType: worker
      configPatches:
        - op: add
          path: /machine/kubelet/extraArgs
          value:
            rotate-server-certificates: "true"
---
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-credentials
  namespace: ${CLUSTER_NAMESPACE}
  labels:
    platform.ionos.com/secret-type: "proxmox-credentials"
type: Opaque
stringData:
  token: "${PROXMOX_TOKEN}"
  secret: "${PROXMOX_SECRET}"
  url: "https://${PROXMOX_HOST}:${PROXMOX_PORT}"
EOF

print_success "Cluster YAML files created successfully!"
print_info "Generated files:"
print_info "  • ${KUBECTL_CONFIG_FILE}"
print_info "  • ${CLUSTERCTL_CONFIG_FILE}"


echo
# Initialize CAPI with Proxmox, Talos providers and IPAM in-cluster
clusterctl init \
  --config ${CLUSTERCTL_CONFIG_PATH}/${CLUSTERCTL_CONFIG_FILE} \
  --target-namespace ${CLUSTER_NAMESPACE} \
  --infrastructure proxmox \
  --bootstrap talos \
  --control-plane talos \
  --ipam in-cluster

# Wait for all pods to be in Running state before proceeding
echo
print_info "Waiting for all pods to be in Running state..."
while true; do
    # Get pods that are not in Running, Succeeded, or Completed state
    non_ready_pods=$(kubectl get pods -A --no-headers | grep -v -E "(Running|Succeeded|Completed)" | wc -l)
    
    if [ "$non_ready_pods" -eq 0 ]; then
        print_success "All pods are now in Running state"
        break
    else
        print_info "Waiting for $non_ready_pods pod(s) to be ready..."
        sleep 5
    fi
done

# Wait for webhook services to be ready (simplified check)
echo
print_info "Waiting for Cluster API controllers to be ready..."

# Simple wait - just give the controllers some time to initialize
sleep 30

# Check if basic cluster API resources are available
if kubectl api-resources | grep -q "clusters.cluster.x-k8s.io" >/dev/null 2>&1; then
    print_success "Cluster API resources are available"
else
    print_warning "Cluster API resources not fully ready, but proceeding..."
fi

# Apply all kubectl configurations from the dedicated directory with retry logic
echo
print_info "Applying all Kubernetes configurations from ${KUBECTL_CONFIG_PATH}..."

apply_success=false
max_apply_attempts=5
apply_attempt=0

while [ "$apply_success" = false ] && [ "$apply_attempt" -lt "$max_apply_attempts" ]; do
    apply_attempt=$((apply_attempt + 1))
    
    if [ "$apply_attempt" -gt 1 ]; then
        print_info "Retrying kubectl apply (attempt $apply_attempt/$max_apply_attempts)..."
        # Wait a bit longer between retries to allow webhook to fully initialize
        sleep 10
    fi
    
    if kubectl apply -f "${KUBECTL_CONFIG_PATH}" --request-timeout=${KUBECTL_APPLY_TIMEOUT} 2>/tmp/kubectl_apply_error.log; then
        print_success "Successfully applied all Kubernetes configurations"
        apply_success=true
    else
        # Check if the error is specifically about webhook connection
        if grep -q "connect: connection refused" /tmp/kubectl_apply_error.log 2>/dev/null; then
            print_warning "Webhook connection refused, waiting for webhook to be fully ready..."
            if [ "$apply_attempt" -lt "$max_apply_attempts" ]; then
                print_info "Will retry in 10 seconds..."
            fi
        else
            print_error "kubectl apply failed with a different error:"
            cat /tmp/kubectl_apply_error.log 2>/dev/null || echo "Could not read error log"
            break
        fi
    fi
done

# Clean up temporary error log
rm -f /tmp/kubectl_apply_error.log

if [ "$apply_success" = false ]; then
    print_error "Failed to apply configurations after $max_apply_attempts attempts"
    exit 1
fi
