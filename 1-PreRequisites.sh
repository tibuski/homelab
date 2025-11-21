#!/bin/sh

# Prerequisites installation script for kubectl, talosctl, clusterctl, and kind
# Supports Arch Linux, Debian, and Alpine Linux
# POSIX compliant

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            arch|manjaro)
                echo "arch"
                ;;
            debian|ubuntu)
                echo "debian"
                ;;
            alpine)
                echo "alpine"
                ;;
            *)
                echo "unknown"
                ;;
        esac
    else
        echo "unknown"
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to ask for user confirmation
confirm_installation() {
    tool="$1"
    echo
    printf "Do you want to install %s? [y/N]: " "$tool"
    read -r REPLY
    case "$REPLY" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to install kubectl
install_kubectl() {
    distro="$1"
    
    print_info "Installing kubectl..."
    
    case "$distro" in
        arch)
            sudo pacman -S kubectl
            ;;
        debian)
            # Install kubectl using the official Kubernetes repository
            if ! command_exists curl; then
                sudo apt-get update
                sudo apt-get install -y curl
            fi
            
            # Add Kubernetes GPG key and repository
            curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
            echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
            sudo apt-get update
            sudo apt-get install kubectl
            ;;
        alpine)
            # Install kubectl from Alpine repositories
            sudo apk add kubectl
            ;;
    esac
    
    print_success "kubectl installed successfully"
}

# Function to install talosctl
install_talosctl() {
    distro="$1"
    
    print_info "Installing talosctl..."
    
    case "$distro" in
        arch)
            # Install from AUR or download binary
            if command_exists yay; then
                yay -S talosctl-bin
            elif command_exists paru; then
                paru -S talosctl-bin
            else
                # Download binary directly
                if confirm_installation "talosctl binary"; then
                    install_talosctl_binary
                else
                    print_warning "Skipping talosctl binary installation"
                    return 1
                fi
            fi
            ;;
        debian|alpine)
            # Download binary directly for Debian and Alpine
            if confirm_installation "talosctl binary"; then
                install_talosctl_binary
            else
                print_warning "Skipping talosctl binary installation"
                return 1
            fi
            ;;
    esac
    
    print_success "talosctl installed successfully"
}

# Function to install talosctl binary
install_talosctl_binary() {
    if ! command_exists curl; then
        case "$(detect_distro)" in
            debian)
                sudo apt-get update && sudo apt-get install -y curl
                ;;
            alpine)
                sudo apk add --no-cache curl
                ;;
        esac
    fi
    
    # Get the latest version and download
    TALOS_VERSION=$(curl -s https://api.github.com/repos/siderolabs/talos/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    curl -Lo talosctl https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/talosctl-linux-amd64
    chmod +x talosctl
    sudo mv talosctl /usr/local/bin/
}

# Function to install kind
install_kind() {
    distro="$1"
    
    print_info "Installing kind..."
    
    case "$distro" in
        arch)
            # Try AUR first, then fallback to binary download
            if command_exists yay; then
                yay -S kind-bin
            elif command_exists paru; then
                paru -S kind-bin
            else
                # Download binary directly for Arch
                if confirm_installation "kind binary"; then
                    if ! command_exists curl; then
                        sudo pacman -S curl
                    fi
                    
                    KIND_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
                    curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64
                    chmod +x ./kind
                    sudo mv ./kind /usr/local/bin/kind
                else
                    print_warning "Skipping kind binary installation"
                    return 1
                fi
            fi
            ;;
        debian)
            # Download binary directly
            if confirm_installation "kind binary"; then
                if ! command_exists curl; then
                    sudo apt-get update
                    sudo apt-get install -y curl
                fi
                
                # Install kind binary
                KIND_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
                curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64
                chmod +x ./kind
                sudo mv ./kind /usr/local/bin/kind
            else
                print_warning "Skipping kind binary installation"
                return 1
            fi
            ;;
        alpine)
            # Download binary directly for Alpine
            if confirm_installation "kind binary"; then
                if ! command_exists curl; then
                    sudo apk add curl
                fi
                
                KIND_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
                curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64
                chmod +x ./kind
                sudo mv ./kind /usr/local/bin/kind
            else
                print_warning "Skipping kind binary installation"
                return 1
            fi
            ;;
    esac
    
    print_success "kind installed successfully"
}

# Function to install clusterctl
install_clusterctl() {
    distro="$1"
    
    print_info "Installing clusterctl..."
    
    case "$distro" in
        arch)
            # Try AUR first, then fallback to binary download
            if command_exists yay; then
                yay -S clusterctl-bin
            elif command_exists paru; then
                paru -S clusterctl-bin
            else
                # Download binary directly for Arch
                if confirm_installation "clusterctl binary"; then
                    install_clusterctl_binary
                else
                    print_warning "Skipping clusterctl binary installation"
                    return 1
                fi
            fi
            ;;
        debian|alpine)
            # Download binary directly for Debian and Alpine
            if confirm_installation "clusterctl binary"; then
                install_clusterctl_binary
            else
                print_warning "Skipping clusterctl binary installation"
                return 1
            fi
            ;;
    esac
    
    print_success "clusterctl installed successfully"
}

# Function to install clusterctl binary
install_clusterctl_binary() {
    if ! command_exists curl; then
        case "$(detect_distro)" in
            debian)
                sudo apt-get update && sudo apt-get install -y curl
                ;;
            alpine)
                sudo apk add curl
                ;;
            arch)
                sudo pacman -S curl
                ;;
        esac
    fi
    
    # Get the latest version and download
    CLUSTERCTL_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/cluster-api/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    curl -Lo clusterctl https://github.com/kubernetes-sigs/cluster-api/releases/download/${CLUSTERCTL_VERSION}/clusterctl-linux-amd64
    chmod +x clusterctl
    sudo mv clusterctl /usr/local/bin/
}

# Function to check and manage Docker
check_docker() {
    print_info "Checking Docker installation..."
    
    if command_exists docker; then
        print_success "Docker is installed"
        
        # Check if Docker daemon is running
        if systemctl is-active --quiet docker 2>/dev/null; then
            print_success "Docker is running"
        else
            print_warning "Docker is installed but not running."
            echo
            printf "Do you want to start Docker? [y/N]: "
            read -r REPLY
            if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ] || [ "$REPLY" = "yes" ] || [ "$REPLY" = "YES" ]; then
                print_info "Starting Docker..."
                
                # Try to start Docker with systemctl
                if command_exists systemctl; then
                    sudo systemctl start docker
                    sudo systemctl enable docker
                    
                    # Verify Docker started successfully
                    if systemctl is-active --quiet docker; then
                        print_success "Docker started successfully"
                    else
                        print_error "Failed to start Docker with systemctl"
                    fi
                else
                    # For Alpine Linux or systems without systemctl
                    print_warning "systemctl not available. Trying to start Docker with service command..."
                    if command_exists service; then
                        sudo service docker start
                        print_success "Docker service started"
                    elif command_exists rc-service; then
                        sudo rc-service docker start
                        sudo rc-update add docker default
                        print_success "Docker service started (Alpine OpenRC)"
                    else
                        print_warning "Could not start Docker automatically. Please start Docker manually."
                    fi
                fi
            else
                print_warning "Skipping Docker startup. You may need to start it manually later."
            fi
        fi
        
        # Check if current user is in docker group
        if groups | grep -q docker 2>/dev/null; then
            print_success "User is in docker group"
        else
            print_warning "User is not in docker group."
            echo
            printf "Do you want to add current user to docker group? [y/N]: "
            read -r REPLY
            if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ] || [ "$REPLY" = "yes" ] || [ "$REPLY" = "YES" ]; then
                print_info "Adding user to docker group..."
                sudo usermod -aG docker "$USER"
                print_warning "Please log out and log back in for group changes to take effect"
            else
                print_warning "Skipping docker group addition. You may need to run docker with sudo."
            fi
        fi
    else
        print_warning "Docker is not installed!"
        print_warning "Please install Docker manually before proceeding."
        print_warning "Visit: https://docs.docker.com/engine/install/"
        return 1
    fi
}

# Main execution
main() {
    print_info "Starting prerequisites installation..."
    
    # Detect distribution
    DISTRO=$(detect_distro)
    
    if [ "$DISTRO" = "unknown" ]; then
        print_error "Unsupported Linux distribution. This script supports Arch Linux, Debian, and Alpine Linux."
        exit 1
    fi
    
    print_info "Detected distribution: $DISTRO"
    
    # Update package manager
    case "$DISTRO" in
        arch)
            print_info "Updating package database..."
            sudo pacman -Sy
            ;;
        debian)
            print_info "Updating package database..."
            sudo apt-get update
            ;;
        alpine)
            print_info "Updating package database..."
            sudo apk update
            ;;
    esac
    
    # Install tools if they don't exist
    if ! command_exists kubectl; then
        install_kubectl "$DISTRO" || print_warning "kubectl installation failed or was skipped"
    else
        print_success "kubectl is already installed"
    fi
    
    if ! command_exists talosctl; then
        install_talosctl "$DISTRO" || print_warning "talosctl installation failed or was skipped"
    else
        print_success "talosctl is already installed"
    fi
    
    if ! command_exists kind; then
        install_kind "$DISTRO" || print_warning "kind installation failed or was skipped"
    else
        print_success "kind is already installed"
    fi
    
    if ! command_exists clusterctl; then
        install_clusterctl "$DISTRO" || print_warning "clusterctl installation failed or was skipped"
    else
        print_success "clusterctl is already installed"
    fi
    
    # Check Docker
    check_docker
    
    print_success "Prerequisites check completed!"
    
    # Display installed versions
    echo
    print_info "Installed versions:"
    if command_exists kubectl; then
        echo -e "${GREEN}kubectl${NC}: $(kubectl version --client --short 2>/dev/null || kubectl version --client -o json 2>/dev/null | grep gitVersion | cut -d'"' -f4 || echo 'version check failed')"
    fi
    if command_exists talosctl; then
        echo -e "${GREEN}talosctl${NC}: $(talosctl version 2>/dev/null | grep -A5 'Client:' | grep 'Tag:' | awk '{print $2}' || echo 'version check failed')"
    fi
    if command_exists kind; then
        echo -e "${GREEN}kind${NC}: $(kind version 2>/dev/null || echo 'version check failed')"
    fi
    if command_exists clusterctl; then
        echo -e "${GREEN}clusterctl${NC}: $(clusterctl version 2>/dev/null | grep 'GitVersion:' | sed 's/.*GitVersion:"\([^"]*\)".*/\1/' || echo 'version check failed')"
    fi
    if command_exists docker; then
        echo -e "${GREEN}docker${NC}: $(docker --version 2>/dev/null || echo 'version check failed')"
    else
        echo -e "${GREEN}docker${NC}: Not installed"
    fi
}

# Run main function
main "$@"