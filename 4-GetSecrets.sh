#!/bin/sh
# Get kubeconfig and talosconfig from deployed cluster
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check cluster status
check_cluster_status() {
    print_info "Checking cluster status..."
    
    if ! kubectl get cluster "${CLUSTER_NAME}" -n "${CLUSTER_NAMESPACE}" >/dev/null 2>&1; then
        print_error "Cluster '${CLUSTER_NAME}' not found in namespace '${CLUSTER_NAMESPACE}'"
        print_error "Please ensure the cluster has been deployed using 3-ClusterAPI.sh"
        exit 1
    fi
    
    # Check if cluster is ready
    cluster_phase=$(kubectl get cluster "${CLUSTER_NAME}" -n "${CLUSTER_NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    
    if [ "$cluster_phase" != "Provisioned" ]; then
        print_warning "Cluster phase is: ${cluster_phase}"
        print_warning "Cluster may not be fully ready. Continuing anyway..."
    else
        print_success "Cluster is in 'Provisioned' state"
    fi
}

# Function to get kubeconfig
get_kubeconfig() {
    print_info "Retrieving kubeconfig for cluster '${CLUSTER_NAME}'..."
    
    # Create kubectl config directory if it doesn't exist
    if [ ! -d "${KUBECTL_CONFIG_PATH}" ]; then
        mkdir -p "${KUBECTL_CONFIG_PATH}"
        print_info "Created directory: ${KUBECTL_CONFIG_PATH}"
    fi
    
    # Get the kubeconfig secret
    kubeconfig_secret_name="${CLUSTER_NAME}-kubeconfig"
    
    if ! kubectl get secret "${kubeconfig_secret_name}" -n "${CLUSTER_NAMESPACE}" >/dev/null 2>&1; then
        print_error "Kubeconfig secret '${kubeconfig_secret_name}' not found"
        print_error "The cluster may not be fully provisioned yet"
        return 1
    fi
    
    # Extract kubeconfig from secret
    kubectl get secret "${kubeconfig_secret_name}" -n "${CLUSTER_NAMESPACE}" \
        -o jsonpath='{.data.value}' | base64 -d > "${KUBECTL_CONFIG_PATH}/${KUBECTL_CONFIG_FILE}"
    
    if [ -f "${KUBECTL_CONFIG_PATH}/${KUBECTL_CONFIG_FILE}" ]; then
        print_success "Kubeconfig saved to: ${KUBECTL_CONFIG_PATH}/${KUBECTL_CONFIG_FILE}"
        
        # Set proper permissions
        chmod 600 "${KUBECTL_CONFIG_PATH}/${KUBECTL_CONFIG_FILE}"
        
        # Test the kubeconfig
        print_info "Testing kubeconfig connectivity..."
        if KUBECONFIG="${KUBECTL_CONFIG_PATH}/${KUBECTL_CONFIG_FILE}" kubectl cluster-info >/dev/null 2>&1; then
            print_success "Kubeconfig is valid and cluster is accessible"
        else
            print_warning "Kubeconfig retrieved but cluster may not be fully ready"
        fi
    else
        print_error "Failed to save kubeconfig"
        return 1
    fi
}

# Function to get talosconfig
get_talosconfig() {
    print_info "Retrieving talosconfig for cluster '${CLUSTER_NAME}'..."
    
    # Create talos config directory if it doesn't exist
    talos_config_dir="${PWD}/talos-configs"
    if [ ! -d "${talos_config_dir}" ]; then
        mkdir -p "${talos_config_dir}"
        print_info "Created directory: ${talos_config_dir}"
    fi
    
    # Get the talosconfig secret
    talosconfig_secret_name="${CLUSTER_NAME}-talosconfig"
    
    if ! kubectl get secret "${talosconfig_secret_name}" -n "${CLUSTER_NAMESPACE}" >/dev/null 2>&1; then
        print_error "Talosconfig secret '${talosconfig_secret_name}' not found"
        print_error "The cluster may not be fully provisioned yet"
        return 1
    fi
    
    # Extract talosconfig from secret
    talosconfig_file="${talos_config_dir}/talosconfig"
    kubectl get secret "${talosconfig_secret_name}" -n "${CLUSTER_NAMESPACE}" \
        -o jsonpath='{.data.talosconfig}' | base64 -d > "${talosconfig_file}"
    
    if [ -f "${talosconfig_file}" ]; then
        print_success "Talosconfig saved to: ${talosconfig_file}"
        
        # Set proper permissions
        chmod 600 "${talosconfig_file}"
        
        # Test talosconfig if talosctl is available
        if command_exists talosctl; then
            print_info "Testing talosconfig connectivity..."
            print_info "Running: talosctl --talosconfig=\"${talosconfig_file}\" version --endpoints=\"${CONTROL_PLANE_ENDPOINT_IP}\" --nodes=\"${CONTROL_PLANE_ENDPOINT_IP}\""
            
            # Capture both stdout and stderr for better error reporting
            talos_test_output=$(talosctl --talosconfig="${talosconfig_file}" version --endpoints="${CONTROL_PLANE_ENDPOINT_IP}" --nodes="${CONTROL_PLANE_ENDPOINT_IP}" 2>&1)
            talos_test_result=$?
            
            if [ $talos_test_result -eq 0 ]; then
                print_success "Talosconfig is valid and control plane is accessible"
                print_info "Talos API responded successfully"
            else
                print_warning "Talosconfig retrieved but control plane may not be fully ready"
                print_warning "Talos connectivity test failed with exit code: ${talos_test_result}"
                print_warning "Error details: ${talos_test_output}"
                print_info "This is normal if the cluster is still bootstrapping"
                print_info "You can retry the talosctl commands manually once the cluster is ready"
            fi
        else
            print_info "talosctl not found in PATH, skipping connectivity test"
        fi
    else
        print_error "Failed to save talosconfig"
        return 1
    fi
}

# Function to display usage information
show_usage_info() {
    print_success "=========================================="
    print_success "  CLUSTER FULLY FUNCTIONAL ON PROXMOX!"
    print_success "=========================================="
    print_info "Your Talos Kubernetes cluster is now running independently on Proxmox"
    print_info "The management cluster (kind) is no longer required for normal operations"
    echo ""
    
    print_info "Verifying cluster health:"
    printf "  kubectl --kubeconfig=%s/%s get nodes\n" "${KUBECTL_CONFIG_PATH}" "${KUBECTL_CONFIG_FILE}"
    printf "  kubectl --kubeconfig=%s/%s get pods -A\n" "${KUBECTL_CONFIG_PATH}" "${KUBECTL_CONFIG_FILE}"
    echo ""
    
    print_info "Configuration files retrieved successfully!"
    echo ""
    print_info "To use the kubeconfig:"
    printf "  kubectl --kubeconfig=%s/%s get nodes\n" "${KUBECTL_CONFIG_PATH}" "${KUBECTL_CONFIG_FILE}"
    printf "  kubectl --kubeconfig=%s/%s get pods -A\n" "${KUBECTL_CONFIG_PATH}" "${KUBECTL_CONFIG_FILE}"
    echo ""
    
    if [ -f "./talos-configs/talosconfig" ]; then
        print_info "To use the talosconfig:"
        printf "  talosctl --talosconfig=./talos-configs/talosconfig --endpoints=%s --nodes=%s version\n" "${CONTROL_PLANE_ENDPOINT_IP}" "${CONTROL_PLANE_ENDPOINT_IP}"
        printf "  talosctl --talosconfig=./talos-configs/talosconfig --endpoints=%s --nodes=%s health\n" "${CONTROL_PLANE_ENDPOINT_IP}" "${CONTROL_PLANE_ENDPOINT_IP}"
        echo ""
        print_info "To check Talos extensions and system info:"
        printf "  talosctl --talosconfig=./talos-configs/talosconfig --endpoints=%s --nodes=%s get extensions\n" "${CONTROL_PLANE_ENDPOINT_IP}" "${CONTROL_PLANE_ENDPOINT_IP}"
        printf "  talosctl --talosconfig=./talos-configs/talosconfig --endpoints=%s --nodes=%s services\n" "${CONTROL_PLANE_ENDPOINT_IP}" "${CONTROL_PLANE_ENDPOINT_IP}"
        printf "  talosctl --talosconfig=./talos-configs/talosconfig --endpoints=%s --nodes=%s logs kubelet\n" "${CONTROL_PLANE_ENDPOINT_IP}" "${CONTROL_PLANE_ENDPOINT_IP}"
        printf "  talosctl --talosconfig=./talos-configs/talosconfig --endpoints=%s --nodes=%s dmesg\n" "${CONTROL_PLANE_ENDPOINT_IP}" "${CONTROL_PLANE_ENDPOINT_IP}"
        printf "  talosctl --talosconfig=./talos-configs/talosconfig --endpoints=%s --nodes=%s logs machined\n" "${CONTROL_PLANE_ENDPOINT_IP}" "${CONTROL_PLANE_ENDPOINT_IP}"
        echo ""
        print_info "To check guest agents and system processes:"
        printf "  talosctl --talosconfig=./talos-configs/talosconfig --endpoints=%s --nodes=%s ps\n" "${CONTROL_PLANE_ENDPOINT_IP}" "${CONTROL_PLANE_ENDPOINT_IP}"
        printf "  talosctl --talosconfig=./talos-configs/talosconfig --endpoints=%s --nodes=%s dmesg | grep -i qemu\n" "${CONTROL_PLANE_ENDPOINT_IP}" "${CONTROL_PLANE_ENDPOINT_IP}"
        printf "  talosctl --talosconfig=./talos-configs/talosconfig --endpoints=%s --nodes=%s dmesg | grep -i guest\n" "${CONTROL_PLANE_ENDPOINT_IP}" "${CONTROL_PLANE_ENDPOINT_IP}"
        printf "  talosctl --talosconfig=./talos-configs/talosconfig --endpoints=%s --nodes=%s ls /dev/ | grep virtio\n" "${CONTROL_PLANE_ENDPOINT_IP}" "${CONTROL_PLANE_ENDPOINT_IP}"
        printf "  talosctl --talosconfig=./talos-configs/talosconfig --endpoints=%s --nodes=%s dashboard\n" "${CONTROL_PLANE_ENDPOINT_IP}" "${CONTROL_PLANE_ENDPOINT_IP}"
        echo ""
    fi
    
    print_info "Cluster endpoint: https://${CONTROL_PLANE_ENDPOINT_IP}:6443"
}

# Main execution
main() {
    print_info "Starting retrieval of cluster configuration files..."
    print_info "Cluster: ${CLUSTER_NAME} (namespace: ${CLUSTER_NAMESPACE})"
    echo ""
    
    # Check required commands
    if ! command_exists kubectl; then
        print_error "kubectl is required but not found in PATH"
        print_error "Please install kubectl and ensure it's in your PATH"
        exit 1
    fi
    
    # Verify we can connect to the management cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes management cluster"
        print_error "Please ensure your kubeconfig is properly configured for the management cluster"
        exit 1
    fi
    
    print_success "Connected to management cluster"
    
    # Check cluster status
    check_cluster_status
    
    echo ""
    
    # Get kubeconfig
    if get_kubeconfig; then
        echo ""
    else
        print_error "Failed to retrieve kubeconfig"
        exit 1
    fi
    
    # Get talosconfig
    if get_talosconfig; then
        echo ""
    else
        print_warning "Failed to retrieve talosconfig, but kubeconfig was successful"
    fi
    
    # Show usage information
    show_usage_info
}

# Run main function
main "$@"
