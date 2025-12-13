#!/bin/bash

# Enhanced Script to add/update Jim AUR repository on Arch Linux
# Author: James "Jim" Ed Randson
# These repositories are running under OBS (openSUSE Build Service)

# Remove set -e to prevent unexpected exits
# set -e

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

print_debug() {
    echo -e "${CYAN}[DEBUG]${NC} $1"
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
    print_debug "Checking if repository exists in $PACMAN_CONF..."
    
    if [ ! -f "$PACMAN_CONF" ]; then
        print_error "pacman.conf not found at $PACMAN_CONF"
        return 1
    fi
    
    if grep -q "^\[$REPO_NAME\]" "$PACMAN_CONF" 2>/dev/null; then
        REPO_EXISTS=true
        print_info "Repository $REPO_NAME found in configuration"
        return 0
    else
        REPO_EXISTS=false
        print_info "Repository $REPO_NAME not found in configuration"
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
    key=$(curl -fsSL "$KEY_URL" 2>/dev/null)
    local curl_exit=$?
    
    if [[ $curl_exit -ne 0 ]] || [[ -z "$key" ]]; then
        print_warning "Failed to download GPG key (curl exit code: $curl_exit)"
        print_info "Repository will use 'Optional TrustAll' signature level"
        echo "none"
        return 0
    fi
    
    print_info "Processing GPG key..."
    fingerprint=$(gpg --quiet --with-colons --import-options show-only --import --fingerprint <<< "${key}" 2>/dev/null | awk -F: '$1 == "fpr" { print $10; exit }')
    
    if [[ -z "$fingerprint" ]]; then
        print_warning "Failed to extract key fingerprint"
        print_info "Repository will use 'Optional TrustAll' signature level"
        echo "none"
        return 0
    fi
    
    print_info "Key fingerprint: $fingerprint"
    
    # Initialize pacman keyring if needed
    print_info "Initializing pacman keyring..."
    pacman-key --init 2>/dev/null || true
    
    # Add and sign the key
    print_info "Adding GPG key to pacman keyring..."
    if pacman-key --add - <<< "${key}" 2>/dev/null; then
        print_success "GPG key added"
    else
        print_warning "Key may already exist or failed to add"
    fi
    
    print_info "Locally signing the key..."
    if pacman-key --lsign-key "${fingerprint}" 2>/dev/null; then
        print_success "Key signed successfully"
    else
        print_warning "Key signing failed or already signed"
    fi
    
    print_success "GPG key setup completed"
    echo "$fingerprint"
}

# Function to add repository
add_repository() {
    print_info "Adding repository to $PACMAN_CONF..."
    
    # Verify pacman.conf exists and is writable
    if [ ! -f "$PACMAN_CONF" ]; then
        print_error "Cannot find $PACMAN_CONF"
        return 1
    fi
    
    if [ ! -w "$PACMAN_CONF" ]; then
        print_error "$PACMAN_CONF is not writable"
        return 1
    fi
    
    # Backup pacman.conf first
    print_info "Creating backup of $PACMAN_CONF..."
    BACKUP_FILE="$PACMAN_CONF.backup.$(date +%Y%m%d_%H%M%S)"
    
    if cp "$PACMAN_CONF" "$BACKUP_FILE" 2>/dev/null; then
        print_success "Backup created: $BACKUP_FILE"
    else
        print_error "Failed to create backup"
        return 1
    fi
    
    # Check if repository already exists (double check)
    if grep -q "^\[$REPO_NAME\]" "$PACMAN_CONF" 2>/dev/null; then
        print_warning "Repository section already exists in $PACMAN_CONF"
        print_info "Skipping repository addition"
        return 0
    fi
    
    # Add repository to pacman.conf (before [core] repository for priority)
    print_info "Writing repository configuration..."
    
    # Create temporary file with new content
    TEMP_CONF=$(mktemp)
    
    if grep -q "^\[core\]" "$PACMAN_CONF"; then
        # Insert before [core] section
        awk -v repo="$REPO_NAME" -v url="$REPO_URL" '
        /^\[core\]/ && !inserted {
            print "# Jim AUR Repository"
            print "[" repo "]"
            print "Server = " url
            print "SigLevel = Optional TrustAll"
            print ""
            inserted=1
        }
        {print}
        ' "$PACMAN_CONF" > "$TEMP_CONF"
        
        if [ $? -eq 0 ]; then
            mv "$TEMP_CONF" "$PACMAN_CONF"
            print_success "Repository added before [core] section"
        else
            print_error "Failed to modify pacman.conf"
            rm -f "$TEMP_CONF"
            return 1
        fi
    else
        # Append to end of file if [core] not found
        {
            cat "$PACMAN_CONF"
            echo ""
            echo "# Jim AUR Repository"
            echo "[$REPO_NAME]"
            echo "Server = $REPO_URL"
            echo "SigLevel = Optional TrustAll"
        } > "$TEMP_CONF"
        
        if [ $? -eq 0 ]; then
            mv "$TEMP_CONF" "$PACMAN_CONF"
            print_success "Repository added to end of configuration"
        else
            print_error "Failed to modify pacman.conf"
            rm -f "$TEMP_CONF"
            return 1
        fi
    fi
    
    print_success "Repository successfully added to $PACMAN_CONF"
    return 0
}

# Function to update repository databases
update_databases() {
    print_info "Updating package databases..."
    
    if pacman -Sy --noconfirm 2>&1 | tee /tmp/pacman_update.log | grep -v "warning:"; then
        print_success "Package databases updated successfully"
        return 0
    else
        print_warning "Package database update completed (check /tmp/pacman_update.log)"
        return 0
    fi
}

# Function to verify repository is working
verify_repository() {
    print_info "Verifying repository configuration..."
    
    if pacman -Sl "$REPO_NAME" &>/dev/null; then
        print_success "Repository is accessible and working!"
        PACKAGE_COUNT=$(pacman -Sl "$REPO_NAME" 2>/dev/null | wc -l)
        print_info "Available packages in repository: $PACKAGE_COUNT"
        return 0
    else
        print_warning "Repository added but verification failed"
        print_info "This might be normal if the repository is empty or temporarily unavailable"
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
    
    print_debug "Running as root: OK"
    
    # Check if we're on Arch Linux
    if ! command -v pacman &> /dev/null; then
        print_error "This script is designed for Arch Linux systems with pacman"
        exit 1
    fi
    
    print_debug "Pacman found: OK"
    
    # Check architecture - only x86_64 is supported
    CURRENT_ARCH=$(uname -m)
    if [[ "$CURRENT_ARCH" != "x86_64" ]]; then
        print_error "Unsupported architecture: $CURRENT_ARCH"
        print_error "This repository only supports x86_64 architecture"
        print_info "Your current architecture: $CURRENT_ARCH"
        exit 1
    fi
    
    print_success "Architecture check passed: x86_64"
    echo
    
    # Check if repository already exists
    print_debug "Calling check_repo_exists function..."
    check_repo_exists
    local check_exit=$?
    print_debug "check_repo_exists returned: $check_exit, REPO_EXISTS=$REPO_EXISTS"
    echo
    
    if [[ $REPO_EXISTS == true ]]; then
        print_warning "Repository $REPO_NAME already exists in $PACMAN_CONF"
        print_info "Proceeding with GPG key update only..."
        echo
        
        # Update GPG key
        fingerprint=$(setup_gpg_key)
        echo
        
        # Update package databases
        update_databases
        echo
        
        # Verify repository
        verify_repository
        
        echo
        print_success "Repository GPG key updated successfully!"
        echo
        print_info "Repository Information:"
        print_info "  Name: $REPO_NAME"
        print_info "  URL: $REPO_URL"
        if [[ "$fingerprint" != "none" ]]; then
            print_info "  Key Fingerprint: $fingerprint"
        fi
        print_info "  Status: Already configured, key updated"
        
    else
        print_info "Repository not found. Proceeding with full installation..."
        echo
        
        # Setup GPG key
        print_debug "Starting GPG key setup..."
        fingerprint=$(setup_gpg_key)
        print_debug "GPG setup completed with fingerprint: $fingerprint"
        echo
        
        # Add repository
        print_debug "Starting repository addition..."
        if add_repository; then
            print_debug "Repository addition successful"
        else
            print_error "Repository addition failed"
            exit 1
        fi
        echo
        
        # Update package databases
        print_debug "Starting database update..."
        update_databases
        echo
        
        # Verify repository
        print_debug "Starting repository verification..."
        verify_repository
        
        echo
        print_success "Repository setup completed successfully!"
        echo
        print_info "Repository Information:"
        print_info "  Name: $REPO_NAME"
        print_info "  URL: $REPO_URL"
        if [[ "$fingerprint" != "none" ]]; then
            print_info "  Key Fingerprint: $fingerprint"
        fi
        print_info "  Status: Newly configured"
        echo
        print_info "Backup of original pacman.conf saved"
    fi
    
    echo
    print_info "You can now install packages from this repository using:"
    print_info "  pacman -S <package-name>"
    echo
    print_info "To list available packages:"
    print_info "  pacman -Sl $REPO_NAME"
    echo
    print_info "To remove this repository later, edit $PACMAN_CONF"
    print_info "and remove the [$REPO_NAME] section"
    echo
    
    print_success "Script execution completed!"
}

# Trap errors for debugging
trap 'print_error "Script failed at line $LINENO with exit code $?"' ERR

# Execute main function
print_debug "Starting script execution..."
main
exit_code=$?

print_debug "Script finished with exit code: $exit_code"
exit $exit_code
