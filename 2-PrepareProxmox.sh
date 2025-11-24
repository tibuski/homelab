#!/bin/sh

# Prepare Proxmox Secrets and templates for Talos and Kubernetes deployment
# POSIX compliant
#
# PREREQUISITES:
# - Talos ISO must be present in Proxmox ISO storage
# - Download Talos ISO from: https://factory.talos.dev/?arch=amd64&cmdline-set=true&extensions=-&extensions=siderolabs%2Fqemu-guest-agent&platform=nocloud&target=cloud
# - Upload the ISO to your Proxmox storage (e.g., Data storage)
# - Update TALOS_ISO_PATH variable in 0-Homelab.conf to match your storage path

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

print_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

print_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

# Display prerequisites
print_info "Prerequisites Check:"
print_warning "Talos nocloud with QEMU agent ISO must be present in Proxmox ISO storage"
print_info "Download from:https://factory.talos.dev/?arch=amd64&cmdline-set=true&extensions=-&extensions=siderolabs%2Fqemu-guest-agent&platform=nocloud&target=cloud"
print_info "Upload the ISO to your Proxmox storage and update TALOS_ISO_PATH in 0-Homelab.conf"
print_info "Check if a newer version of TALOS_QEMU_GUEST_AGENT_URL is available at https://github.com/siderolabs/extensions/pkgs/container/qemu-guest-agent/versions"
echo

print_info "Using configuration from 0-Homelab.conf"
print_info "Proxmox Host: ${PROXMOX_HOST}:${PROXMOX_PORT}"
print_info "Starting Proxmox preparation..."
print_info "Template VMID: ${TEMPLATE_VMID}"
print_info "Talos ISO Path: ${TALOS_ISO_PATH}"
echo

# ===============================================================================
# PROXMOX USER AND TOKEN SETUP
# ===============================================================================

print_info "Checking Proxmox API user and token..."

# Set default user if empty
if [ -z "${PROXMOX_USER}" ]; then
    PROXMOX_USER="capi"
fi

# Construct full user (add @pve if not present)
PROXMOX_FULL_USER="${PROXMOX_USER}@pve"

# Check if user exists and create if needed
if ! ssh -q root@"${PROXMOX_HOST}" "pveum user list | grep -q '${PROXMOX_FULL_USER}'"; then
    print_info "Creating Proxmox user ${PROXMOX_FULL_USER}..."
    ssh -q root@"${PROXMOX_HOST}" << PROXMOX_USER_SETUP
        # Create user
        pveum user add ${PROXMOX_FULL_USER}
        
        # Add PVEAdmin role
        pveum aclmod / -user ${PROXMOX_FULL_USER} -role PVEAdmin
        
        # Create API token
        echo "Creating API token..."
        pveum user token add ${PROXMOX_FULL_USER} ${PROXMOX_TOKEN_NAME} -privsep 0
        echo "============================================"
PROXMOX_USER_SETUP
    
    print_success "Proxmox user and token created successfully"
    echo
    print_warning "REQUIRED ACTION:"
    print_warning "1. Copy the token secret from above"
    print_warning "2. Update PROXMOX_SECRET (Value in the table above) in 0-Homelab.conf with the copied secret"
    print_warning "3. Run this script again to continue"
    print_warning "The secret will not be shown again!"
    echo
    exit 0
else
    print_success "Proxmox user ${PROXMOX_FULL_USER} already exists"
    
    # Check if token exists
    if ! ssh -q root@"${PROXMOX_HOST}" "pveum user token list ${PROXMOX_FULL_USER} 2>/dev/null | grep -q '${PROXMOX_TOKEN_NAME}'"; then
        print_info "Creating API token for user ${PROXMOX_FULL_USER}..."
        ssh -q root@"${PROXMOX_HOST}" << TOKEN_CREATE
            echo "============================================"
            echo "Creating API token..."
            pveum user token add ${PROXMOX_FULL_USER} ${PROXMOX_TOKEN_NAME} -privsep 0
            echo "============================================"
TOKEN_CREATE
        print_success "API token created successfully"
        echo
        print_warning "REQUIRED ACTION:"
        print_warning "1. Copy the token secret from above"
        print_warning "2. Update PROXMOX_SECRET in 0-Homelab.conf with the copied secret"
        print_warning "3. Run this script again to continue"
        print_warning "The secret will not be shown again!"
        echo
        exit 0
    else
        print_success "API token ${PROXMOX_TOKEN_NAME} already exists for user ${PROXMOX_FULL_USER}"
    fi
fi
echo

# ===============================================================================
# VM TEMPLATE CREATION ON PROXMOX
# ===============================================================================

print_info "Creating Talos VM template on Proxmox host ${PROXMOX_HOST}..."

# Check if template already exists
echo "[QM] Checking if VM template ${TEMPLATE_VMID} already exists"
if ssh -q root@"${PROXMOX_HOST}" "qm status ${TEMPLATE_VMID} >/dev/null 2>&1"; then
    print_success "Template VM ${TEMPLATE_VMID} already exists. Skipping creation."
else
    print_info "Creating new VM template ${TEMPLATE_VMID}..."
    
    # Show all commands that will be sent to Proxmox with resolved variables
    echo "[QM] The following exact commands will be executed on Proxmox host ${PROXMOX_HOST}:"
    echo "[QM] qm create ${TEMPLATE_VMID} --name \"${TEMPLATE_NAME}\" --memory ${TEMPLATE_MEMORY} --cores ${TEMPLATE_CORES} --net0 virtio,bridge=${TEMPLATE_BRIDGE} --onboot ${TEMPLATE_ONBOOT}"
    if [ -n "${TEMPLATE_CPU_FLAGS}" ]; then
        echo "[QM] qm set ${TEMPLATE_VMID} --cpu ${TEMPLATE_CPU},flags=${TEMPLATE_CPU_FLAGS}"
    else
        echo "[QM] qm set ${TEMPLATE_VMID} --cpu ${TEMPLATE_CPU}"
    fi
    echo "[QM] qm set ${TEMPLATE_VMID} --scsi0 ${TEMPLATE_STORAGE}:${TEMPLATE_DISK_SIZE} --boot order=scsi0 --scsihw virtio-scsi-single"
    echo "[QM] qm set ${TEMPLATE_VMID} --ide2 ${TALOS_ISO_PATH},media=cdrom"
    echo "[QM] qm set ${TEMPLATE_VMID} --agent enabled=1"
    echo "[QM] qm set ${TEMPLATE_VMID} --tags ${TEMPLATE_TAG}"
    echo "[QM} qm set ${TEMPLATE_VMID} --onboot ${TEMPLATE_ONBOOT}"
    echo "[QM] qm template ${TEMPLATE_VMID}"
    echo
    
    # Create VM and configure it in a single SSH session
    ssh -q root@"${PROXMOX_HOST}" << PROXMOX_COMMANDS
        # Create VM
        qm create ${TEMPLATE_VMID} \
            --name "${TEMPLATE_NAME}" \
            --memory ${TEMPLATE_MEMORY} \
            --cores ${TEMPLATE_CORES} \
            --net0 virtio,bridge=${TEMPLATE_BRIDGE} \
            --onboot ${TEMPLATE_ONBOOT}
        
        # Set CPU type and flags
        if [ -n "${TEMPLATE_CPU_FLAGS}" ]; then
            qm set ${TEMPLATE_VMID} --cpu "${TEMPLATE_CPU},flags=${TEMPLATE_CPU_FLAGS}"
        else
            qm set ${TEMPLATE_VMID} --cpu ${TEMPLATE_CPU}
        fi

        # Configure storage and boot
        qm set ${TEMPLATE_VMID} \
            --scsi0 ${TEMPLATE_STORAGE}:${TEMPLATE_DISK_SIZE} \
            --boot order=scsi0 \
            --scsihw virtio-scsi-single
        
        # Attach Talos ISO
        qm set ${TEMPLATE_VMID} \
            --ide2 ${TALOS_ISO_PATH},media=cdrom
        
        # Enable QEMU guest agent
        qm set ${TEMPLATE_VMID} \
            --agent enabled=1
        
        # Add tags to template
        qm set ${TEMPLATE_VMID} \
            --tags ${TEMPLATE_TAG}
        
        # Convert to template
        qm template ${TEMPLATE_VMID}
        
        echo "Template ${TEMPLATE_VMID} created successfully"
PROXMOX_COMMANDS
    
    print_success "Talos VM template creation completed."
fi

print_success "Proxmox preparation completed successfully!"