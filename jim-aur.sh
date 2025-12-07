#!/bin/bash

# Enhanced Script to add/update Jim AUR repository on Arch Linux
# Author: James "Jim" Ed Randson
# These repositories are running under OBS (openSUSE Build Service)

set -e  # Exit on any error

# Clear terminal for clean start
clear

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Repository configuration
REPO_NAME="home_jimedrand_Arch"
REPO_URL="https://download.opensuse.org/repositories/home:/jimedrand/Arch/\$arch"
PACMAN_CONF="/etc/pacman.conf"
REPO_EXISTS=false

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

print_header() {
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}         ${CYAN}Jim AUR Repository Setup & Update Tool${NC}         ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}║${NC}              Author: James Ed Randson                  ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Function to check if repository exists
check_repo_exists() {
    if grep -q "^\[$REPO_NAME\]" "$PACMAN_CONF"; then
        REPO_EXISTS=true
        return 0
    else
        REPO_EXISTS=false
        return 1
    fi
}

# Function to setup GPG key
setup_gpg_key() {
    print_info "Setting up GPG key for repository..."
    
    # Get architecture
    ARCH=$(uname -m)
    KEY_URL="https://download.opensuse.org/repositories/home:jimedrand/Arch/$ARCH/home_jimedrand_Arch.key"
    
    print_info "Downloading GPG key from $KEY_URL..."
    
    # Download and process the key
    key=$(curl -fsSL "$KEY_URL")
    if [[ $? -ne 0 ]] || [[ -z "$key" ]]; then
        print_error "Failed to download GPG key"
        return 1
    fi
    
    print_info "Processing GPG key..."
    fingerprint=$(gpg --quiet --with-colons --import-options show-only --import --fingerprint <<< "${key}" | awk -F: '$1 == "fpr" { print $10 }')
    
    if [[ -z "$fingerprint" ]]; then
        print_error "Failed to extract key fingerprint"
        return 1
    fi
    
    print_info "Key fingerprint: $fingerprint"
    
    # Initialize pacman keyring if needed
    print_info "Initializing pacman keyring..."
    pacman-key --init 2>/dev/null || true
    
    # Add and sign the key
    print_info "Adding GPG key to pacman keyring..."
    pacman-key --add - <<< "${key}" 2>/dev/null || print_warning "Key may already exist"
    
    print_info "Locally signing the key..."
    pacman-key --lsign-key "${fingerprint}"
    
    print_success "GPG key setup completed"
    echo "$fingerprint"
}

# Function to add repository
add_repository() {
    print_info "Adding repository to $PACMAN_CONF..."
    
    # Backup pacman.conf first
    print_info "Creating backup of $PACMAN_CONF..."
    cp "$PACMAN_CONF" "$PACMAN_CONF.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Add repository to pacman.conf (before [core] repository for priority)
    if grep -q "^\[core\]" "$PACMAN_CONF"; then
        # Insert before [core] section
        sed -i "/^\[core\]/i [$REPO_NAME]\nServer = $REPO_URL\nSigLevel = Optional TrustAll\n" "$PACMAN_CONF"
    else
        # Append to end of file if [core] not found
        echo -e "\n[$REPO_NAME]\nServer = $REPO_URL\nSigLevel = Optional TrustAll" >> "$PACMAN_CONF"
    fi
    
    print_success "Repository added to $PACMAN_CONF"
}

# Function to update repository databases
update_databases() {
    print_info "Updating package databases..."
    if pacman -Sy; then
        print_success "Package databases updated successfully"
    else
        print_error "Failed to update package databases"
        return 1
    fi
}

# Main execution
main() {
    print_header
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Check if we're on Arch Linux
    if ! command -v pacman &> /dev/null; then
        print_error "This script is designed for Arch Linux systems with pacman"
        exit 1
    fi
    
    # Check architecture - only x86_64 is supported
    CURRENT_ARCH=$(uname -m)
    if [[ "$CURRENT_ARCH" != "x86_64" ]]; then
        print_error "Unsupported architecture: $CURRENT_ARCH"
        print_error "This repository only supports x86_64 architecture"
        print_info "Your current architecture: $CURRENT_ARCH"
        exit 1
    fi
    
    print_success "Architecture check passed: x86_64"
    
    # Check if repository already exists
    check_repo_exists
    
    if [[ $REPO_EXISTS == true ]]; then
        print_warning "Repository $REPO_NAME already exists in $PACMAN_CONF"
        print_info "Proceeding with GPG key update only..."
        echo
        
        # Update GPG key
        fingerprint=$(setup_gpg_key)
        
        # Update package databases
        update_databases
        
        echo
        print_success "Repository GPG key updated successfully!"
        echo
        print_info "Repository Information:"
        print_info "  Name: $REPO_NAME"
        print_info "  URL: $REPO_URL"
        print_info "  Key Fingerprint: $fingerprint"
        print_info "  Status: Already configured, key updated"
        
    else
        print_info "Repository not found. Proceeding with full installation..."
        echo
        
        # Setup GPG key
        fingerprint=$(setup_gpg_key)
        echo
        
        # Add repository
        add_repository
        echo
        
        # Update package databases
        update_databases
        
        echo
        print_success "Repository setup completed successfully!"
        echo
        print_info "Repository Information:"
        print_info "  Name: $REPO_NAME"
        print_info "  URL: $REPO_URL"
        print_info "  Key Fingerprint: $fingerprint"
        print_info "  Status: Newly configured"
        echo
        print_info "Backup of original pacman.conf saved as: $PACMAN_CONF.backup.*"
    fi
    
    echo
    print_info "To remove this repository later, edit $PACMAN_CONF and remove the [$REPO_NAME] section"
    echo
}

# Execute main function
main

exit 0
