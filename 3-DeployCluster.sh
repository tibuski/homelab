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
apiVersion: cluster.x-k8s.io/v1beta2
kind: Cluster
metadata:
  name: ${CLUSTER_NAME}
  namespace: ${CLUSTER_NAMESPACE}
spec:
  controlPlaneRef:
    apiGroup: controlplane.cluster.x-k8s.io
    kind: TalosControlPlane
    name: talos-control-plane
  infrastructureRef:
    apiGroup: infrastructure.cluster.x-k8s.io
    kind: ProxmoxCluster
    name: ${PROXMOX_CLUSTER_NAME}
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
      strategicPatches:
        - |
          machine:
            install:
              disk: /dev/sda
              image: ${TALOS_FACTORY_IMAGE}
              extraKernelArgs:
                - "talos.interface=eth0=dhcp"
                - "vip=${CONTROL_PLANE_ENDPOINT_IP}"
            network:
              interfaces:
                - interface: "eth0"
                  dhcp: true
                  vip:
                    ip: "${CONTROL_PLANE_ENDPOINT_IP}"
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
          disk: ${TEMPLATE_DISK}
          sizeGb: ${TEMPLATE_DISK_SIZE}
      network:
        default:
          bridge: vmbr0
          model: virtio
      checks:
          skipCloudInitStatus: true
          skipQemuGuestAgent: true
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
      strategicPatches:
        - |
          machine:
            install:
              disk: /dev/sda
              image: ${TALOS_FACTORY_IMAGE}
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
print_info "Running : clusterctl init --config ${CLUSTERCTL_CONFIG_PATH}/${CLUSTERCTL_CONFIG_FILE} --target-namespace ${CLUSTER_NAMESPACE} --infrastructure proxmox --bootstrap talos --control-plane talos --ipam in-cluster"
print_info "Note: Suppressing harmless unrecognized format warnings from cert-manager CRDs"

# Filter out the harmless format warnings while keeping important output
clusterctl init \
  --config ${CLUSTERCTL_CONFIG_PATH}/${CLUSTERCTL_CONFIG_FILE} \
  --target-namespace ${CLUSTER_NAMESPACE} \
  --infrastructure proxmox \
  --bootstrap talos \
  --control-plane talos \
  --ipam in-cluster 2>&1 | grep -v "unrecognized format"

# Check available CRD versions before applying
echo
print_info "Checking available Talos CRD versions..."
kubectl api-resources | grep -i talos || print_warning "No Talos CRDs found"
echo

print_info "Checking TalosControlPlane CRD versions..."
kubectl get crd taloscontrolplanes.controlplane.cluster.x-k8s.io -o jsonpath='{.spec.versions[*].name}' 2>/dev/null | tr ' ' '\n' || print_warning "TalosControlPlane CRD not found"
echo

# Wait for webhooks to be ready
echo
print_info "Waiting for Cluster API webhooks to be ready..."

# Function to check if webhook is responding
check_webhook_ready() {
    # Try to get a non-existent ProxmoxCluster - if webhook is ready, we get a proper error, not connection refused
    kubectl get proxmoxcluster non-existent-cluster 2>&1 | grep -v "connection refused" >/dev/null
    return $?
}

# Wait for webhook to be ready with timeout
webhook_timeout=300  # 5 minutes
webhook_elapsed=0
webhook_interval=10

print_info "Checking webhook availability (timeout: ${webhook_timeout}s)..."

while [ $webhook_elapsed -lt $webhook_timeout ]; do
    if check_webhook_ready; then
        print_success "Webhooks are ready!"
        break
    fi
    
    printf "."
    sleep $webhook_interval
    webhook_elapsed=$((webhook_elapsed + webhook_interval))
done

echo ""

if [ $webhook_elapsed -ge $webhook_timeout ]; then
    print_error "Timeout waiting for webhooks to be ready"
    print_warning "You may need to wait longer or check cluster status manually"
    print_info "Try running: kubectl get pods -A | grep webhook"
    exit 1
fi

# Additional wait for all pods to be fully ready
print_info "Waiting for all system pods to be ready..."
kubectl wait --for=condition=Ready pods --all -A --timeout=180s || print_warning "Some pods may still be starting"

# Apply all kubectl configurations from the dedicated directory
echo
print_info "Applying all Kubernetes configurations from ${KUBECTL_CONFIG_PATH}..."
kubectl apply -f "${KUBECTL_CONFIG_PATH}"

echo
print_success "Cluster deployment initiated successfully!"
echo
print_info "To follow logs of commands sent to Proxmox:"
printf "  # Find all CAPI provider deployments:\n"
printf "  kubectl get deployments -A | grep -E '(proxmox|talos|capi)'\n"
printf "  kubectl get pods -A | grep -E '(proxmox|talos|capi)'\n"
echo
printf "  # Follow Proxmox provider logs (shows VM creation and Proxmox API calls):\n"
printf "  kubectl --context kind-${MANAGEMENT_CLUSTER_NAME} logs -f -n default -l control-plane=controller-manager | grep capmox\n"
echo
printf "  # Follow Talos bootstrap provider logs (for extension/configuration issues):\n"
printf "  kubectl --context kind-${MANAGEMENT_CLUSTER_NAME} logs -f -n default -l control-plane=controller-manager | grep cabpt\n"
echo
printf "  # Check machine bootstrap status:\n"
printf "  kubectl get machine -n ${CLUSTER_NAMESPACE} -o wide\n"
printf "  kubectl describe machine -n ${CLUSTER_NAMESPACE}\n"
echo
printf "  # Check Proxmox VMs being created:\n"
printf "  # Log into Proxmox web interface: https://${PROXMOX_HOST}:${PROXMOX_PORT}\n"
echo
print_info "Once the cluster is 'Provisioned', run ./4-GetSecrets.sh to retrieve credentials"
