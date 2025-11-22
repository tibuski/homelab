#!/bin/sh

# Proxmox Cleanup Script: Find and destroy VMs/Templates with tag cluster-api-talos
# POSIX compliant shell script

set -e  # Exit on any error

# Source shared configuration
if [ -f "./0-Homelab.conf" ]; then
    . ./0-Homelab.conf
else
    printf "[ERROR] Configuration file 0-Homelab.conf not found!\n"
    printf "Please ensure 0-Homelab.conf is in the same directory as this script.\n"
    exit 1
fi

# Parse command line arguments
FORCE_DELETE=false

for arg in "$@"; do
    case $arg in
        -f|--force)
            FORCE_DELETE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Find and destroy VMs/Templates with tag '${TEMPLATE_TAG}'"
            echo ""
            echo "OPTIONS:"
            echo "  -f, --force    Skip confirmation prompt and proceed with deletion"
            echo "  -h, --help     Show this help message"
            echo ""
            echo "WARNING: This script will PERMANENTLY DELETE VMs and templates!"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

print_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

print_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

# Function to check SSH connectivity
check_ssh() {
    if ! command -v ssh >/dev/null 2>&1; then
        print_error "ssh command not found. This script requires SSH access to Proxmox."
        exit 1
    fi
    
    print_info "Testing SSH connectivity to Proxmox host: ${PROXMOX_HOST}"
    if ! ssh -T -o ConnectTimeout=10 -o BatchMode=yes root@"${PROXMOX_HOST}" "echo 'Connection successful'" >/dev/null 2>&1; then
        print_error "Cannot connect to Proxmox host ${PROXMOX_HOST} via SSH."
        print_error "Please ensure SSH access is configured for root user."
        exit 1
    fi
    print_success "SSH connectivity confirmed"
}

# Function to confirm deletion with user
confirm_deletion() {
    local resource_count="$1"
    
    # Skip confirmation if force flag is set
    if [ "$FORCE_DELETE" = "true" ]; then
        print_info "Force mode enabled - proceeding with deletion of $resource_count resources..."
        return 0
    fi
    
    echo
    print_warning "WARNING: This will PERMANENTLY DELETE $resource_count resources!"
    print_warning "This action is IRREVERSIBLE!"
    echo
    printf "Do you want to proceed? Type 'yes' to confirm: "
    read -r confirmation
    
    case "$confirmation" in
        yes|YES)
            print_info "Proceeding with deletion..."
            return 0
            ;;
        *)
            print_info "Operation cancelled by user."
            return 1
            ;;
    esac
}

# Function to delete a VM or template
delete_resource() {
    local type="$1"
    local vmid="$2"
    local name="$3"
    
    print_info "Deleting $type $name (ID: $vmid)..."
    
    # Execute deletion on Proxmox host
    ssh -T root@"${PROXMOX_HOST}" << DELETE_SCRIPT 2>/dev/null
# Stop VM if it's running (templates can't be stopped)
if [ "$type" = "VM" ]; then
    STATUS=\$(qm status $vmid 2>/dev/null | awk '{print \$2}')
    if [ "\$STATUS" = "running" ]; then
        echo "  Stopping VM $vmid..."
        qm stop $vmid >/dev/null 2>&1
        sleep 3
    fi
fi

# Destroy the VM/Template with all associated disks
echo "  Destroying $type $vmid..."
qm destroy $vmid --purge --destroy-unreferenced-disks >/dev/null 2>&1

if [ \$? -eq 0 ]; then
    echo "SUCCESS"
else
    echo "FAILED"
fi
DELETE_SCRIPT
}

# Function to find and display VMs/templates with the tag
find_and_display_resources() {
    print_info "Searching for VMs/Templates with tag: ${TEMPLATE_TAG}"
    echo "---"
    
    # Create temporary file to store results
    temp_file="/tmp/proxmox_scan_$$"
    
    # Execute the scan on Proxmox host and capture results
    ssh -T root@"${PROXMOX_HOST}" << 'FIND_SCRIPT' > "$temp_file" 2>/dev/null
# Loop through all VM IDs
for VMID in $(qm list 2>/dev/null | awk '{print $1}' | tail -n +2); do
    # Skip if VMID is empty or not numeric
    case "$VMID" in
        ''|*[!0-9]*) continue ;;
    esac
    
    # Check if VM has the specified tag
    if qm config "$VMID" 2>/dev/null | grep -q "tags:.*${TEMPLATE_TAG}"; then
        
        # Get VM name from qm list  
        VM_NAME=$(qm list 2>/dev/null | awk -v vmid="$VMID" '$1 == vmid {print $2}')
        
        # Skip if name is empty
        [ -z "$VM_NAME" ] && continue
        
        # Check if it's a template
        if qm config "$VMID" 2>/dev/null | grep -q "template: 1"; then
            echo "TEMPLATE:$VMID:$VM_NAME"
        else
            echo "VM:$VMID:$VM_NAME"
        fi
    fi
done
FIND_SCRIPT
    
    # Filter only lines that match our expected format (TYPE:VMID:NAME)
    grep -E "^(VM|TEMPLATE):[0-9]+:" "$temp_file" > "${temp_file}.filtered" 2>/dev/null || true
    
    # Check if any resources were found
    if [ ! -s "${temp_file}.filtered" ]; then
        print_info "No VMs or templates found with tag '${TEMPLATE_TAG}'"
        rm -f "$temp_file" "${temp_file}.filtered"
        echo "NONE:0"
        return 1
    fi
    
    # Display found resources
    resource_count=0
    while IFS=':' read -r type vmid name; do
        # Skip empty lines or malformed entries
        [ -z "$type" ] || [ -z "$vmid" ] || [ -z "$name" ] && continue
        resource_count=$((resource_count + 1))
        printf "  %d. %s %s (ID: %s)\n" "$resource_count" "$type" "$name" "$vmid"
    done < "${temp_file}.filtered"
    
    echo "---"
    print_success "Found $resource_count resources with tag '${TEMPLATE_TAG}'"
    
    # Return the filtered temp file path and count for processing
    echo "${temp_file}.filtered:$resource_count"
}

# Function to process deletion of all resources
process_deletions() {
    local filtered_file="$1"
    local success_count=0
    local total_count=0
    
    print_info "Starting deletion process..."
    echo
    
    while IFS=':' read -r type vmid name; do
        # Skip empty lines or malformed entries
        [ -z "$type" ] || [ -z "$vmid" ] || [ -z "$name" ] && continue
        
        total_count=$((total_count + 1))
        
        # Delete the resource and check result
        result=$(delete_resource "$type" "$vmid" "$name")
        
        if echo "$result" | grep -q "SUCCESS"; then
            print_success "Successfully deleted $type $name (ID: $vmid)"
            success_count=$((success_count + 1))
        else
            print_error "Failed to delete $type $name (ID: $vmid)"
        fi
        echo
    done < "$filtered_file"
    
    # Summary
    echo "---"
    if [ "$success_count" -eq "$total_count" ]; then
        print_success "All $total_count resources deleted successfully!"
    elif [ "$success_count" -eq 0 ]; then
        print_error "Failed to delete any resources!"
    else
        print_warning "Deleted $success_count out of $total_count resources"
    fi
}

# Main function
main() {
    print_info "Proxmox Cleanup Script"
    print_info "======================"
    print_info "Proxmox Host: ${PROXMOX_HOST}:${PROXMOX_PORT}"
    print_info "Target Tag: ${TEMPLATE_TAG}"
    echo
    
    # Check SSH connectivity
    check_ssh
    echo
    
    # Find and display resources
    find_and_display_resources > "/tmp/find_output_$$"
    
    # Extract file path and count from the last line of output
    result_line=$(tail -1 "/tmp/find_output_$$")
    filtered_file=$(echo "$result_line" | cut -d: -f1)
    resource_count=$(echo "$result_line" | cut -d: -f2)
    
    # Show the output (excluding the result line)
    head -n -1 "/tmp/find_output_$$"
    rm -f "/tmp/find_output_$$"
    
    # Check if any resources were found
    if [ "$filtered_file" = "NONE" ] || [ "$resource_count" = "0" ] || [ ! -f "$filtered_file" ]; then
        rm -f "/tmp/proxmox_scan_$$" "/tmp/proxmox_scan_$$.filtered"
        return 0
    fi
    
    # Confirm deletion with user
    if confirm_deletion "$resource_count"; then
        process_deletions "$filtered_file"
    fi
    
    # Clean up temporary files
    rm -f "/tmp/proxmox_scan_$$" "/tmp/proxmox_scan_$$.filtered"
}

# Run main function
main "$@"
