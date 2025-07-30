#!/bin/bash

# Script to add Jim AUR repository on Arch Linux
# Author: James "Jim" Ed Randson
# These repositories are running under OBS (openSUSE Build Service)

set -e  # Exit on any error

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

print_info "Adding Jim AUR repository to Arch Linux..."

# Repository configuration
REPO_NAME="home_jimedrand_Arch"
REPO_URL="https://download.opensuse.org/repositories/home:/jimedrand/Arch/\$arch"
PACMAN_CONF="/etc/pacman.conf"

# Backup pacman.conf first
print_info "Creating backup of $PACMAN_CONF..."
cp "$PACMAN_CONF" "$PACMAN_CONF.backup.$(date +%Y%m%d_%H%M%S)"

# Setup GPG key first
print_info "Setting up GPG key for repository..."

# Get architecture
ARCH=$(uname -m)
KEY_URL="https://download.opensuse.org/repositories/home:jimedrand/Arch/$ARCH/home_jimedrand_Arch.key"

print_info "Downloading GPG key from $KEY_URL..."

# Download and process the key
key=$(curl -fsSL "$KEY_URL")
if [[ $? -ne 0 ]] || [[ -z "$key" ]]; then
    print_error "Failed to download GPG key"
    exit 1
fi

print_info "Processing GPG key..."
fingerprint=$(gpg --quiet --with-colons --import-options show-only --import --fingerprint <<< "${key}" | awk -F: '$1 == "fpr" { print $10 }')

if [[ -z "$fingerprint" ]]; then
    print_error "Failed to extract key fingerprint"
    exit 1
fi

print_info "Key fingerprint: $fingerprint"

# Initialize pacman keyring if needed
print_info "Initializing pacman keyring..."
pacman-key --init

# Add and sign the key
print_info "Adding GPG key to pacman keyring..."
pacman-key --add - <<< "${key}"

print_info "Locally signing the key..."
pacman-key --lsign-key "${fingerprint}"

print_success "GPG key setup completed"

# Now add repository to pacman.conf

# Check if repository is already added
if grep -q "\[$REPO_NAME\]" "$PACMAN_CONF"; then
    print_warning "Repository $REPO_NAME already exists in $PACMAN_CONF"
    read -p "Do you want to continue and update it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Exiting without changes"
        exit 0
    fi
    
    # Remove existing repository entry
    print_info "Removing existing repository entry..."
    sed -i "/^\[$REPO_NAME\]/,/^$/d" "$PACMAN_CONF"
fi

# Add repository to pacman.conf (before [core] repository for priority)
print_info "Adding repository to $PACMAN_CONF..."
if grep -q "^\[core\]" "$PACMAN_CONF"; then
    # Insert before [core] section
    sed -i "/^\[core\]/i [$REPO_NAME]\nServer = $REPO_URL\n" "$PACMAN_CONF"
else
    # Append to end of file if [core] not found
    echo -e "\n[$REPO_NAME]\nServer = $REPO_URL" >> "$PACMAN_CONF"
fi

print_success "Repository added to $PACMAN_CONF"

# Update package databases
print_info "Updating package databases..."
pacman -Sy

print_success "Repository setup completed successfully!"
echo
print_info "Repository Information:"
print_info "  Name: $REPO_NAME"
print_info "  URL: $REPO_URL"
print_info "  Key Fingerprint: $fingerprint"
echo
print_info "To remove this repository later, edit $PACMAN_CONF and remove the [$REPO_NAME] section"
print_info "Backup of original pacman.conf saved as: $PACMAN_CONF.backup.*"