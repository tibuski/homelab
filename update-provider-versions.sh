#!/bin/bash
# Update Cluster API provider versions to latest releases
# This script fetches the latest release versions from GitHub API and updates the configuration

set -e

CONFIG_FILE="./0-Homelab.conf"
TEMP_FILE=$(mktemp)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to get latest release version from GitHub API
get_latest_version() {
    local repo=$1
    local version
    
    print_info "Fetching latest version for ${repo}..."
    
    # Use GitHub API to get latest release
    version=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | \
              grep '"tag_name":' | \
              sed -E 's/.*"([^"]+)".*/\1/')
    
    if [ -z "$version" ]; then
        print_error "Failed to fetch latest version for ${repo}"
        return 1
    fi
    
    echo "$version"
}

# Function to update URL in config file
update_url() {
    local variable_name=$1
    local repo=$2
    local asset_name=$3
    local version
    
    if ! version=$(get_latest_version "$repo"); then
        return 1
    fi
    
    local new_url="https://github.com/${repo}/releases/download/${version}/${asset_name}"
    
    # Update the variable in the config file
    sed -i "s|^${variable_name}=.*|${variable_name}=\"${new_url}\"|" "$CONFIG_FILE"
    
    print_success "Updated ${variable_name} to version ${version}"
}

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    print_error "Configuration file ${CONFIG_FILE} not found!"
    exit 1
fi

print_info "Updating Cluster API provider versions..."
echo

# Update each provider
update_url "TALOS_BOOTSTRAP_PROVIDER_URL" "siderolabs/cluster-api-bootstrap-provider-talos" "bootstrap-components.yaml"
update_url "TALOS_CONTROL_PLANE_PROVIDER_URL" "siderolabs/cluster-api-control-plane-provider-talos" "control-plane-components.yaml"
update_url "PROXMOX_INFRASTRUCTURE_PROVIDER_URL" "ionos-cloud/cluster-api-provider-proxmox" "infrastructure-components.yaml"

echo
print_success "All provider versions updated successfully!"
print_info "Current versions in ${CONFIG_FILE}:"
echo

# Display current versions
grep -E "(TALOS_BOOTSTRAP_PROVIDER_URL|TALOS_CONTROL_PLANE_PROVIDER_URL|PROXMOX_INFRASTRUCTURE_PROVIDER_URL)" "$CONFIG_FILE"

echo
print_warning "Please review the changes and test your configuration before deploying!"