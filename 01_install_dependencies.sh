#!/bin/bash
# Script: 01_install_dependencies.sh
# Purpose: Initialize environment with system tools, Node.js, and editor tooling

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

CONFIG_OWNER_USER="${SUDO_USER:-$USER}"
CONFIG_OWNER_GROUP="$(id -gn "$CONFIG_OWNER_USER" 2>/dev/null || echo "$CONFIG_OWNER_USER")"
CONFIG_HOME="$(eval echo "~$CONFIG_OWNER_USER")"
CONFIG_ROOT="$CONFIG_HOME/.config"

ensure_config_ownership() {
    local config_root="$1"

    if [ -z "$config_root" ]; then
        print_warning "Config root not set; skipping ownership check"
        return 1
    fi

    if [ ! -d "$config_root" ]; then
        mkdir -p "$config_root" 2>/dev/null || sudo mkdir -p "$config_root"
    fi

    local owner group
    owner=$(stat -c '%U' "$config_root" 2>/dev/null)
    group=$(stat -c '%G' "$config_root" 2>/dev/null)

    if [ "$owner" != "$CONFIG_OWNER_USER" ] || [ "$group" != "$CONFIG_OWNER_GROUP" ]; then
        print_warning "$config_root is owned by $owner:$group; fixing ownership for $CONFIG_OWNER_USER:$CONFIG_OWNER_GROUP"
        if sudo chown -R "$CONFIG_OWNER_USER:$CONFIG_OWNER_GROUP" "$config_root"; then
            print_info "✓ Ownership updated for $config_root"
        else
            print_warning "Failed to update ownership for $config_root"
            return 1
        fi
    fi

    return 0
}

ensure_sudo_installed() {
    if command -v sudo &> /dev/null; then
        print_info "sudo already installed"
        return
    fi

    if [ "$(id -u)" -ne 0 ]; then
        print_error "sudo is required but not installed. Run this script as root or install sudo manually."
        exit 1
    fi

    if [ "$AUTO_YES" = true ]; then
        INSTALL_SUDO="y"
        print_info "AUTO_YES enabled; installing sudo without prompt"
    else
        read -p "sudo is required. Install sudo now? (y/n): " INSTALL_SUDO
    fi

    if [[ "$INSTALL_SUDO" =~ ^[Yy]$ ]]; then
        print_info "Installing sudo..."
        if $PKG_UPDATE_CMD && $PKG_INSTALL_CMD sudo; then
            print_info "✓ sudo installed"
        else
            print_error "Failed to install sudo"
            exit 1
        fi
    else
        print_error "Cannot continue without sudo"
        exit 1
    fi
}

# Parse arguments
AUTO_YES=false
if [[ "$1" == "-y" ]] || [[ "$1" == "--auto" ]]; then
    AUTO_YES=true
fi

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Usage: $0 [-y|--auto]"
    echo "  -y, --auto    Automatically accept all prompts"
    echo "  -h, --help    Show this help message"
    exit 0
fi

# OS/package manager detection
OS_TYPE=""
PKG_INSTALL_CMD=""
PKG_UPDATE_CMD=""
PKG_UPGRADE_CMD=""
PKG_CLEAN_CMD=""
OS_ID=""
OS_NAME=""
OS_VERSION_ID=""

detect_os_package_manager() {
    if [ ! -f /etc/os-release ]; then
        return 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release
    OS_ID="$ID"
    OS_NAME="$NAME"
    OS_VERSION_ID="$VERSION_ID"
    local version_major
    version_major=$(echo "$VERSION_ID" | cut -d. -f1)

    local sudo_prefix="sudo "
    if [ "$(id -u)" -eq 0 ]; then
        sudo_prefix=""
    fi

    if [ "$ID" = "ubuntu" ]; then
        if [ "$version_major" -lt 22 ]; then
            return 1
        fi
        OS_TYPE="ubuntu"
        PKG_INSTALL_CMD="${sudo_prefix}apt install -y"
        PKG_UPDATE_CMD="${sudo_prefix}apt update"
        PKG_UPGRADE_CMD="${sudo_prefix}apt upgrade -y"
        PKG_CLEAN_CMD="${sudo_prefix}apt clean"
        return 0
    fi

    if [[ "$ID" =~ ^(rhel|rocky|almalinux)$ ]]; then
        if [ "$version_major" -lt 9 ]; then
            return 1
        fi
        OS_TYPE="rhel"
        if command -v dnf &> /dev/null; then
            PKG_INSTALL_CMD="${sudo_prefix}dnf install -y"
            PKG_UPDATE_CMD="${sudo_prefix}dnf makecache"
            PKG_UPGRADE_CMD="${sudo_prefix}dnf upgrade -y"
            PKG_CLEAN_CMD="${sudo_prefix}dnf clean all"
        else
            PKG_INSTALL_CMD="${sudo_prefix}yum install -y"
            PKG_UPDATE_CMD="${sudo_prefix}yum makecache"
            PKG_UPGRADE_CMD="${sudo_prefix}yum upgrade -y"
            PKG_CLEAN_CMD="${sudo_prefix}yum clean all"
        fi
        return 0
    fi

    return 1
}

print_info "Initialization Script for Development Environment"
echo ""

print_info "Checking OS version..."
if ! detect_os_package_manager; then
    if [ ! -f /etc/os-release ]; then
        print_error "Cannot determine OS version. /etc/os-release not found."
    elif [ "$OS_ID" = "ubuntu" ]; then
        print_error "This script requires Ubuntu 22.04 or newer. Detected: $OS_ID $OS_VERSION_ID"
    elif [[ "$OS_ID" =~ ^(rhel|rocky|almalinux)$ ]]; then
        print_error "This script requires RHEL/Rocky/AlmaLinux 9 or newer. Detected: $OS_ID $OS_VERSION_ID"
    else
        print_error "Unsupported OS. This script supports Ubuntu 22.04+ and RHEL/Rocky/AlmaLinux 9+. Detected: $OS_ID $OS_VERSION_ID"
    fi
    exit 1
fi

if [ "$OS_TYPE" = "ubuntu" ]; then
    print_info "✓ Ubuntu $OS_VERSION_ID detected"
else
    print_info "✓ $OS_NAME $OS_VERSION_ID detected"
fi

ensure_sudo_installed

# Update system packages
if [ "$AUTO_YES" = true ]; then
    UPDATE_SYSTEM="y"
else
    read -p "Update system packages (package manager update)? (y/n): " UPDATE_SYSTEM
fi

if [[ "$UPDATE_SYSTEM" =~ ^[Yy]$ ]]; then
    print_info "Updating system packages..."
    $PKG_UPDATE_CMD
    if [ $? -ne 0 ]; then
        print_error "Failed to update packages"
        exit 1
    fi
    print_info "✓ System packages updated"
else
    print_info "Skipped system update"
fi

echo ""

# Upgrade system packages
if [ "$AUTO_YES" = true ]; then
    UPGRADE_SYSTEM="y"
else
    read -p "Upgrade system packages (package manager upgrade)? This may take a while. (y/n): " UPGRADE_SYSTEM
fi

if [[ "$UPGRADE_SYSTEM" =~ ^[Yy]$ ]]; then
    print_info "Upgrading system packages..."
    $PKG_UPGRADE_CMD
    if [ $? -ne 0 ]; then
        print_error "Failed to upgrade packages"
        exit 1
    fi
    print_info "✓ System packages upgraded"
else
    print_info "Skipped system upgrade"
fi

echo ""

# Basic Linux essentials installed after upgrades to keep tooling current
if [ "$OS_TYPE" = "ubuntu" ]; then
    BASIC_LINUX_ESSENTIALS=(curl wget zip unzip less vim nano tmux git git-lfs htop nvtop ripgrep bubblewrap)
else
    BASIC_LINUX_ESSENTIALS=(curl wget zip unzip less vim-enhanced nano tmux git git-lfs htop nvtop ripgrep bubblewrap)
fi
if [ "$AUTO_YES" = true ]; then
    INSTALL_BASICS="y"
else
    read -p "Install basic Linux essentials (${BASIC_LINUX_ESSENTIALS[*]})? (y/n): " INSTALL_BASICS
fi

if [[ "$INSTALL_BASICS" =~ ^[Yy]$ ]]; then
    print_info "Installing basic Linux essentials..."
    if $PKG_INSTALL_CMD "${BASIC_LINUX_ESSENTIALS[@]}"; then
        print_info "✓ Basic Linux essentials installed"
    else
        print_warning "Failed to install some basic Linux essentials"
    fi
else
    print_info "Skipped installing basic Linux essentials"
fi

echo ""

# Install ShellCheck for shell script linting
if command -v shellcheck &> /dev/null; then
    print_info "ShellCheck already installed ($(shellcheck --version | awk '/^version:/ {print $2; exit}'))"
else
    if [ "$OS_TYPE" = "ubuntu" ]; then
        SHELLCHECK_PACKAGE="shellcheck"
    else
        SHELLCHECK_PACKAGE="ShellCheck"
    fi

    if [ "$AUTO_YES" = true ]; then
        INSTALL_SHELLCHECK="y"
    else
        read -r -p "Install ShellCheck shell script linter ($SHELLCHECK_PACKAGE)? (y/n): " INSTALL_SHELLCHECK
    fi

    if [[ "$INSTALL_SHELLCHECK" =~ ^[Yy]$ ]]; then
        print_info "Installing ShellCheck..."
        if $PKG_INSTALL_CMD "$SHELLCHECK_PACKAGE"; then
            print_info "✓ ShellCheck installed"
        else
            print_warning "Failed to install ShellCheck package: $SHELLCHECK_PACKAGE"
            if [ "$OS_TYPE" = "rhel" ]; then
                print_warning "On RHEL-compatible systems, ShellCheck is commonly provided by EPEL."
                print_info "Enable EPEL, then rerun this script or install ShellCheck manually."
            fi
        fi
    else
        print_info "Skipped installing ShellCheck"
    fi
fi

echo ""

# Core/build dependencies for ML and Python package compilation
if [ "$OS_TYPE" = "ubuntu" ]; then
    CORE_BUILD_DEPENDENCIES=(
        # Essential build tools
        "build-essential"
        "gcc"
        "g++"
        "make"
        "cmake"
        "pkg-config"
        "protobuf-compiler"

        # NUMA optimization
        "numactl"
        "libnuma-dev"
        "libhwloc-dev"

        # Essential Python dependencies
        "libssl-dev"
        "libffi-dev"
        "liblzma-dev"
        "libbz2-dev"
        "libreadline-dev"
        "libsqlite3-dev"
        "libncurses-dev"
        "zlib1g-dev"
    )
else
    CORE_BUILD_DEPENDENCIES=(
        # Essential build tools
        "gcc"
        "gcc-c++"
        "make"
        "cmake"
        "pkgconf-pkg-config"
        "protobuf-compiler"

        # NUMA optimization
        "numactl"
        "numactl-devel"
        "hwloc-devel"

        # Essential Python dependencies
        "openssl-devel"
        "libffi-devel"
        "zlib-devel"
        "xz-devel"
        "bzip2-devel"
        "readline-devel"
        "ncurses-devel"
        "sqlite-devel"
    )
fi

print_info "Checking core/build dependencies..."
MISSING_CORE_BUILD_DEPENDENCIES=()
for pkg in "${CORE_BUILD_DEPENDENCIES[@]}"; do
    if [ "$OS_TYPE" = "ubuntu" ]; then
        if dpkg -l 2>/dev/null | grep -q "^ii  $pkg"; then
            print_info "  ✓ $pkg"
        else
            print_error "  ✗ $pkg"
            MISSING_CORE_BUILD_DEPENDENCIES+=("$pkg")
        fi
    else
        if rpm -q "$pkg" &> /dev/null; then
            print_info "  ✓ $pkg"
        else
            print_error "  ✗ $pkg"
            MISSING_CORE_BUILD_DEPENDENCIES+=("$pkg")
        fi
    fi
done

CORE_BUILD_DEPENDENCIES_MISSING_COUNT=${#MISSING_CORE_BUILD_DEPENDENCIES[@]}
if [ $CORE_BUILD_DEPENDENCIES_MISSING_COUNT -gt 0 ]; then
    print_warning "Missing ${CORE_BUILD_DEPENDENCIES_MISSING_COUNT} core/build dependencies: ${MISSING_CORE_BUILD_DEPENDENCIES[*]}"
else
    print_info "All core/build dependencies already installed."
fi

INSTALL_CORE_BUILD_DEPENDENCIES="n"
if [ $CORE_BUILD_DEPENDENCIES_MISSING_COUNT -gt 0 ]; then
    if [ "$AUTO_YES" = true ]; then
        INSTALL_CORE_BUILD_DEPENDENCIES="y"
    else
        read -p "Install missing core/build dependencies? (y/n): " INSTALL_CORE_BUILD_DEPENDENCIES
    fi
fi

if [[ "$INSTALL_CORE_BUILD_DEPENDENCIES" =~ ^[Yy]$ ]]; then
    AVAILABLE_SPACE=$(df -BG /var | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$AVAILABLE_SPACE" -lt 5 ]; then
        print_error "Low disk space: ${AVAILABLE_SPACE}GB available on /var"
        print_error "At least 5GB recommended for package installation"
        if [ -n "$PKG_CLEAN_CMD" ]; then
            print_info "Free up space with: $PKG_CLEAN_CMD"
        fi
        exit 1
    fi

    if [ "$AVAILABLE_SPACE" -lt 10 ]; then
        if [ "$AUTO_YES" = true ]; then
            CLEAN_CACHE="y"
        else
            print_warning "Low disk space (${AVAILABLE_SPACE}GB). Clean package cache to free space?"
            read -p "Clean package cache? (y/n): " CLEAN_CACHE
        fi

        if [[ "$CLEAN_CACHE" =~ ^[Yy]$ ]]; then
            print_info "Cleaning package cache to free space..."
            if [ -n "$PKG_CLEAN_CMD" ]; then
                $PKG_CLEAN_CMD
            else
                print_warning "No package cache clean command available for this OS"
            fi
        else
            print_warning "Proceeding without cleaning package cache - installation may fail if space runs out"
        fi
    fi

    print_info "Updating package index before installing core/build dependencies..."
    if ! $PKG_UPDATE_CMD; then
        print_error "Package update failed - check your internet connection and disk space"
        exit 1
    fi

    print_info "Installing missing core/build dependencies..."
    if $PKG_INSTALL_CMD "${MISSING_CORE_BUILD_DEPENDENCIES[@]}"; then
        print_info "✓ Core/build dependencies installed"
    else
        print_error "Failed to install some core/build dependencies"
        exit 1
    fi

    print_info "Checking gcc/g++ version compatibility..."
    if command -v gcc &> /dev/null; then
        GCC_VERSION=$(gcc --version | head -1 | grep -oE '[0-9]+' | head -1)
        print_info "Detected gcc-$GCC_VERSION"

        if command -v g++-$GCC_VERSION &> /dev/null; then
            print_info "✓ g++-$GCC_VERSION already available"
        else
            if [ "$AUTO_YES" = true ]; then
                INSTALL_GPP="y"
            else
                read -p "Install g++-$GCC_VERSION to match gcc-$GCC_VERSION? (y/n): " INSTALL_GPP
            fi

            if [[ "$INSTALL_GPP" =~ ^[Yy]$ ]]; then
                if [ "$OS_TYPE" = "ubuntu" ]; then
                    print_info "Installing g++-$GCC_VERSION to match gcc-$GCC_VERSION..."
                    if $PKG_INSTALL_CMD "g++-$GCC_VERSION"; then
                        print_info "✓ g++-$GCC_VERSION installed"

                        if [ "$AUTO_YES" = true ]; then
                            SET_DEFAULT="y"
                        else
                            read -p "Set g++-$GCC_VERSION as default g++ compiler? (y/n): " SET_DEFAULT
                        fi

                        if [[ "$SET_DEFAULT" =~ ^[Yy]$ ]]; then
                            if sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-$GCC_VERSION 100; then
                                print_info "✓ Set g++-$GCC_VERSION as default g++ compiler"
                            else
                                print_warning "Could not set g++-$GCC_VERSION as default"
                            fi
                        else
                            print_info "Skipped setting g++-$GCC_VERSION as default"
                        fi
                    else
                        print_warning "Could not install g++-$GCC_VERSION - CUDA compilation may fail"
                    fi
                else
                    print_info "✓ gcc-c++ package provides matching g++ version on RHEL-compatible systems"
                fi
            else
                print_warning "Skipped g++-$GCC_VERSION installation - CUDA compilation may fail"
            fi
        fi
    fi
else
    if [ $CORE_BUILD_DEPENDENCIES_MISSING_COUNT -gt 0 ]; then
        print_info "Skipped installing core/build dependencies"
    fi
fi

if command -v ibtop &> /dev/null; then
    print_info "ibtop already installed"
else
    if [ "$AUTO_YES" = true ]; then
        INSTALL_IBTOP="y"
    else
        read -p "Install ibtop (network monitoring tool)? (y/n): " INSTALL_IBTOP
    fi

    if [[ "$INSTALL_IBTOP" =~ ^[Yy]$ ]]; then
        print_info "Installing ibtop network monitoring tool..."
        if curl -fsSL https://raw.githubusercontent.com/JannikSt/ibtop/main/install.sh | bash; then
            print_info "✓ ibtop installed successfully"
        else
            print_warning "Failed to install ibtop"
        fi
    else
        print_info "Skipped ibtop installation"
    fi
fi

if command -v tmux &> /dev/null; then
    TMUX_CONFIG_SOURCE="$(dirname "$0")/configs/.tmux.conf"
    TMUX_CONFIG_TARGET="$HOME/.tmux.conf"

    if [ "$AUTO_YES" = true ]; then
        COPY_TMUX_CONFIG="y"
    else
        read -p "Copy tmux config from $TMUX_CONFIG_SOURCE to $TMUX_CONFIG_TARGET? (y/n): " COPY_TMUX_CONFIG
    fi

    if [[ "$COPY_TMUX_CONFIG" =~ ^[Yy]$ ]]; then
        if [ -f "$TMUX_CONFIG_SOURCE" ]; then
            if cp "$TMUX_CONFIG_SOURCE" "$TMUX_CONFIG_TARGET"; then
                print_info "✓ tmux config copied to $TMUX_CONFIG_TARGET"
            else
                print_warning "Failed to copy tmux config"
            fi
        else
            print_warning "tmux config not found at $TMUX_CONFIG_SOURCE"
        fi
    else
        print_info "Skipped copying tmux config"
    fi
fi

echo ""

# Install nvm (Node Version Manager)
NVM_INSTALL_URL="https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.5/install.sh"
if [ "$AUTO_YES" = true ]; then
    INSTALL_NVM="y"
elif [ -d "$HOME/.nvm" ]; then
    read -p "Update nvm (Node Version Manager)? (y/n): " INSTALL_NVM
else
    read -p "Install nvm (Node Version Manager)? (y/n): " INSTALL_NVM
fi

if [[ "$INSTALL_NVM" =~ ^[Yy]$ ]]; then
    if [ -d "$HOME/.nvm" ]; then
        print_info "Updating nvm..."
    else
        print_info "Downloading and installing nvm..."
    fi

    if ! curl -o- "$NVM_INSTALL_URL" | bash; then
        print_error "Failed to install or update nvm"
        exit 1
    fi

    # Load nvm for current session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    NVM_VERSION=$(nvm --version 2>/dev/null)
    if [ -n "$NVM_VERSION" ]; then
        print_info "✓ nvm ready: $NVM_VERSION"
    else
        print_info "✓ nvm installed or updated"
    fi
else
    print_info "Skipped nvm installation/update"
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

echo ""

# Install Node.js 24
if command -v nvm &> /dev/null; then
    NODE_ALREADY_AVAILABLE=false
    if command -v node &> /dev/null; then
        NODE_ALREADY_AVAILABLE=true
    fi

    if [ "$AUTO_YES" = true ]; then
        INSTALL_NODE="y"
    elif [ "$NODE_ALREADY_AVAILABLE" = true ]; then
        read -p "Update Node.js 24 and npm with nvm? (y/n): " INSTALL_NODE
    else
        read -p "Install Node.js 24? (y/n): " INSTALL_NODE
    fi

    if [[ "$INSTALL_NODE" =~ ^[Yy]$ ]]; then
        CURRENT_NVM_NODE=""
        if [ "$NODE_ALREADY_AVAILABLE" = true ]; then
            print_info "Updating Node.js 24..."
            CURRENT_NVM_NODE=$(nvm current 2>/dev/null || true)
        else
            print_info "Installing Node.js 24..."
        fi

        nvm install 24

        if [ $? -ne 0 ]; then
            print_error "Failed to install or update Node.js 24"
            exit 1
        fi

        UPDATED_NVM_NODE=$(nvm current 2>/dev/null || true)
        if [ -n "$CURRENT_NVM_NODE" ] && [ "$CURRENT_NVM_NODE" != "none" ] && [ "$CURRENT_NVM_NODE" != "system" ] && [ "$CURRENT_NVM_NODE" != "$UPDATED_NVM_NODE" ]; then
            print_info "Reinstalling global npm packages from $CURRENT_NVM_NODE..."
            if ! nvm reinstall-packages "$CURRENT_NVM_NODE"; then
                print_warning "Could not reinstall global npm packages from $CURRENT_NVM_NODE"
            fi
        fi

        nvm alias default 24

        BASHRC_PATH="$CONFIG_HOME/.bashrc"
        if [ ! -f "$BASHRC_PATH" ]; then
            if ! touch "$BASHRC_PATH" 2>/dev/null; then
                sudo touch "$BASHRC_PATH"
                sudo chown "$CONFIG_OWNER_USER:$CONFIG_OWNER_GROUP" "$BASHRC_PATH"
            fi
        fi

        if ! sed -i '/# nvm default Node version (added by 01_install_dependencies.sh)/,/^# End nvm default Node version/d' "$BASHRC_PATH" 2>/dev/null; then
            sudo sed -i '/# nvm default Node version (added by 01_install_dependencies.sh)/,/^# End nvm default Node version/d' "$BASHRC_PATH"
            sudo chown "$CONFIG_OWNER_USER:$CONFIG_OWNER_GROUP" "$BASHRC_PATH"
        fi

        if [ -w "$BASHRC_PATH" ]; then
            cat <<'EOF' >> "$BASHRC_PATH"
# nvm default Node version (added by 01_install_dependencies.sh)
nvm use default >/dev/null 2>&1
hash -r 2>/dev/null || true
# End nvm default Node version
EOF
        else
            cat <<'EOF' | sudo tee -a "$BASHRC_PATH" > /dev/null
# nvm default Node version (added by 01_install_dependencies.sh)
nvm use default >/dev/null 2>&1
hash -r 2>/dev/null || true
# End nvm default Node version
EOF
            sudo chown "$CONFIG_OWNER_USER:$CONFIG_OWNER_GROUP" "$BASHRC_PATH"
        fi
        print_info "✓ nvm default Node version block updated in $BASHRC_PATH"

        nvm use default
        hash -r 2>/dev/null || true
        print_info "✓ Node.js ready"

        # Verify installation
        NODE_VERSION=$(node -v 2>/dev/null)
        NPM_VERSION=$(npm -v 2>/dev/null)
        print_info "Node.js version: $NODE_VERSION"
        print_info "npm version: $NPM_VERSION"
    else
        print_info "Skipped Node.js installation/update"
    fi
else
    print_warning "nvm not found - skipping Node.js 24 installation/update"
fi

echo ""

# Install Bun
if [ -d "$HOME/.bun/bin" ]; then
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
fi

if command -v bun &> /dev/null; then
    if [ "$AUTO_YES" = true ]; then
        UPDATE_BUN="y"
    else
        read -p "Update Bun to the latest stable version? (y/n): " UPDATE_BUN
    fi

    if [[ "$UPDATE_BUN" =~ ^[Yy]$ ]]; then
        print_info "Updating Bun..."
        if bun upgrade; then
            BUN_VERSION=$(bun --version 2>/dev/null)
            if [ -n "$BUN_VERSION" ]; then
                print_info "✓ Bun ready: $BUN_VERSION"
            else
                print_info "✓ Bun updated"
            fi
        else
            print_error "Failed to update Bun"
            exit 1
        fi
    else
        print_info "Skipped Bun update"
    fi
else
    if [ "$AUTO_YES" = true ]; then
        INSTALL_BUN="y"
    else
        read -p "Install Bun JavaScript runtime? (y/n): " INSTALL_BUN
    fi

    if [[ "$INSTALL_BUN" =~ ^[Yy]$ ]]; then
        if ! command -v curl &> /dev/null; then
            print_error "curl not found - install basic Linux essentials before installing Bun"
            exit 1
        fi

        print_info "Installing Bun..."
        if curl -fsSL https://bun.com/install | bash; then
            export BUN_INSTALL="$HOME/.bun"
            export PATH="$BUN_INSTALL/bin:$PATH"
            print_info "✓ Bun installed"

            BUN_VERSION=$(bun --version 2>/dev/null)
            if [ -n "$BUN_VERSION" ]; then
                print_info "Bun version: $BUN_VERSION"
            else
                print_info "Restart your shell or run: source ~/.bashrc"
            fi
        else
            print_error "Failed to install Bun"
            exit 1
        fi
    else
        print_info "Skipped Bun installation"
    fi
fi

echo ""

# Install Rustup
if ! command -v rustup &> /dev/null && [ -f "$HOME/.cargo/env" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.cargo/env"
fi

if command -v rustup &> /dev/null; then
    if [ "$AUTO_YES" = true ]; then
        UPDATE_RUSTUP="y"
    else
        read -p "Update Rust toolchains with rustup? (y/n): " UPDATE_RUSTUP
    fi

    if [[ "$UPDATE_RUSTUP" =~ ^[Yy]$ ]]; then
        print_info "Updating Rust toolchains..."
        if rustup update; then
            RUSTC_VERSION=$(rustc --version 2>/dev/null)
            CARGO_VERSION=$(cargo --version 2>/dev/null)
            RUSTUP_VERSION=$(rustup --version 2>/dev/null | head -1)

            [ -n "$RUSTC_VERSION" ] && print_info "$RUSTC_VERSION"
            [ -n "$CARGO_VERSION" ] && print_info "$CARGO_VERSION"
            [ -n "$RUSTUP_VERSION" ] && print_info "$RUSTUP_VERSION"
        else
            print_error "Failed to update Rust toolchains"
            exit 1
        fi
    else
        print_info "Skipped Rustup update"
    fi
else
    if [ "$AUTO_YES" = true ]; then
        INSTALL_RUSTUP="y"
    else
        read -p "Install Rustup (Rust toolchain manager)? (y/n): " INSTALL_RUSTUP
    fi

    if [[ "$INSTALL_RUSTUP" =~ ^[Yy]$ ]]; then
        if ! command -v curl &> /dev/null; then
            print_error "curl not found - install basic Linux essentials before installing Rustup"
            exit 1
        fi

        print_info "Installing Rustup..."
        if [ "$AUTO_YES" = true ]; then
            RUSTUP_INSTALL_CMD=(sh -s -- -y)
        else
            RUSTUP_INSTALL_CMD=(sh)
        fi

        if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | "${RUSTUP_INSTALL_CMD[@]}"; then
            if [ -f "$HOME/.cargo/env" ]; then
                # shellcheck disable=SC1091
                . "$HOME/.cargo/env"
            fi

            print_info "✓ Rustup installed"

            RUSTC_VERSION=$(rustc --version 2>/dev/null)
            CARGO_VERSION=$(cargo --version 2>/dev/null)
            RUSTUP_VERSION=$(rustup --version 2>/dev/null | head -1)

            [ -n "$RUSTC_VERSION" ] && print_info "$RUSTC_VERSION"
            [ -n "$CARGO_VERSION" ] && print_info "$CARGO_VERSION"
            [ -n "$RUSTUP_VERSION" ] && print_info "$RUSTUP_VERSION"

            if [ -z "$RUSTC_VERSION" ] || [ -z "$CARGO_VERSION" ]; then
                print_info "Restart your shell or run: source ~/.cargo/env"
            fi
        else
            print_error "Failed to install Rustup"
            exit 1
        fi
    else
        print_info "Skipped Rustup installation"
    fi
fi

NVIM_AVAILABLE=false
NVIM_ALREADY_AVAILABLE=false
if command -v nvim &> /dev/null; then
    NVIM_AVAILABLE=true
    NVIM_ALREADY_AVAILABLE=true
fi

# Install latest Neovim (downloaded from GitHub releases)
if [ "$AUTO_YES" = true ]; then
    INSTALL_NVIM_LATEST="y"
elif [ "$NVIM_ALREADY_AVAILABLE" = true ]; then
    read -p "Update latest Neovim (download from GitHub releases)? (y/n): " INSTALL_NVIM_LATEST
else
    read -p "Install latest Neovim (download from GitHub releases)? (y/n): " INSTALL_NVIM_LATEST
fi

if [[ "$INSTALL_NVIM_LATEST" =~ ^[Yy]$ ]]; then
    if ! command -v tar &> /dev/null; then
        print_warning "tar not found - skipping Neovim install"
    elif ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        print_warning "curl or wget not found - skipping Neovim install"
    else
        if [ "$NVIM_ALREADY_AVAILABLE" = true ]; then
            print_info "Updating latest Neovim..."
        else
            print_info "Installing latest Neovim..."
        fi
        NVIM_ARCH="$(uname -m)"
        case "$NVIM_ARCH" in
            x86_64|amd64) NVIM_ASSETS=("nvim-linux-x86_64.tar.gz" "nvim-linux64.tar.gz") ;;
            aarch64|arm64) NVIM_ASSETS=("nvim-linux-arm64.tar.gz") ;;
            *) NVIM_ASSETS=() ;;
        esac

        if [ ${#NVIM_ASSETS[@]} -eq 0 ]; then
            print_warning "Unsupported architecture for Neovim installer: $NVIM_ARCH"
        else
            TMP_DIR="$(mktemp -d)"
            NVIM_TARBALL=""
            for asset in "${NVIM_ASSETS[@]}"; do
                URL="https://github.com/neovim/neovim/releases/latest/download/$asset"
                if command -v curl &> /dev/null; then
                    if curl -fL "$URL" -o "$TMP_DIR/$asset"; then
                        NVIM_TARBALL="$TMP_DIR/$asset"
                        break
                    fi
                else
                    if wget -O "$TMP_DIR/$asset" "$URL"; then
                        NVIM_TARBALL="$TMP_DIR/$asset"
                        break
                    fi
                fi
            done

            if [ -z "$NVIM_TARBALL" ]; then
                print_warning "Failed to download Neovim release from GitHub"
            else
                NVIM_TOP_DIR="$(tar -tf "$NVIM_TARBALL" | head -n1 | cut -d/ -f1)"
                if [ -z "$NVIM_TOP_DIR" ]; then
                    print_warning "Failed to read Neovim archive contents"
                else
                    sudo mkdir -p /opt
                    if sudo tar -C /opt -xzf "$NVIM_TARBALL"; then
                        if sudo ln -sfn "/opt/$NVIM_TOP_DIR/bin/nvim" /usr/local/bin/nvim; then
                            print_info "✓ Latest Neovim installed (symlinked to /usr/local/bin/nvim)"
                            NVIM_AVAILABLE=true
                        else
                            print_warning "Failed to link Neovim binary"
                        fi
                    else
                        print_warning "Failed to extract Neovim archive"
                    fi
                fi
            fi
            rm -rf "$TMP_DIR"
        fi
    fi
fi

# Check if Neovim is available (installed previously or just now)
if command -v nvim &> /dev/null; then
    NVIM_AVAILABLE=true
fi

# Optionally alias vi/vim to Neovim in bashrc (only if installed here)
if [ "$NVIM_AVAILABLE" = true ]; then
    if [ "$AUTO_YES" = true ]; then
        ALIAS_NVIM="y"
    else
        read -p "Alias vi and vim to Neovim in $CONFIG_HOME/.bashrc? (y/n): " ALIAS_NVIM
    fi

    if [[ "$ALIAS_NVIM" =~ ^[Yy]$ ]]; then
        BASHRC_PATH="$CONFIG_HOME/.bashrc"

        if [ ! -f "$BASHRC_PATH" ]; then
            if ! touch "$BASHRC_PATH" 2>/dev/null; then
                sudo touch "$BASHRC_PATH"
                sudo chown "$CONFIG_OWNER_USER:$CONFIG_OWNER_GROUP" "$BASHRC_PATH"
            fi
        fi

        # Remove previous block and any existing vi/vim alias lines
        if ! sed -i '/# Neovim aliases (added by 01_install_dependencies.sh)/,/^# End Neovim aliases/d' "$BASHRC_PATH" 2>/dev/null; then
            sudo sed -i '/# Neovim aliases (added by 01_install_dependencies.sh)/,/^# End Neovim aliases/d' "$BASHRC_PATH"
            sudo chown "$CONFIG_OWNER_USER:$CONFIG_OWNER_GROUP" "$BASHRC_PATH"
        fi
        if ! sed -i '/^alias vi=/d; /^alias vim=/d' "$BASHRC_PATH" 2>/dev/null; then
            sudo sed -i '/^alias vi=/d; /^alias vim=/d' "$BASHRC_PATH"
            sudo chown "$CONFIG_OWNER_USER:$CONFIG_OWNER_GROUP" "$BASHRC_PATH"
        fi

        if [ -w "$BASHRC_PATH" ]; then
            cat <<'EOF' >> "$BASHRC_PATH"
# Neovim aliases (added by 01_install_dependencies.sh)
alias vi='nvim'
alias vim='nvim'
# End Neovim aliases
EOF
        else
            cat <<'EOF' | sudo tee -a "$BASHRC_PATH" > /dev/null
# Neovim aliases (added by 01_install_dependencies.sh)
alias vi='nvim'
alias vim='nvim'
# End Neovim aliases
EOF
            sudo chown "$CONFIG_OWNER_USER:$CONFIG_OWNER_GROUP" "$BASHRC_PATH"
        fi

        print_info "✓ Aliases for vi and vim added to $BASHRC_PATH"
    else
        print_info "Skipped aliasing vi/vim to Neovim"
    fi
fi

# NeoVim config install
if [ "$NVIM_AVAILABLE" = true ]; then
    if [ "$AUTO_YES" = true ]; then
        INSTALL_NVIM_CONFIG="y"
    else
        read -p "Install NeoVim configs provided by the author of this script? (y/n): " INSTALL_NVIM_CONFIG
    fi

    if [[ "$INSTALL_NVIM_CONFIG" =~ ^[Yy]$ ]]; then
    if command -v git &> /dev/null; then
        if ! ensure_config_ownership "$CONFIG_ROOT"; then
            print_warning "Skipping NeoVim config install due to ownership issues"
        else
            NVIM_CONFIG_DIR="$CONFIG_ROOT/nvim"
            NVIM_CONFIG_PARENT="$(dirname "$NVIM_CONFIG_DIR")"

            if [ -d "$NVIM_CONFIG_DIR" ] && [ -z "$(ls -A "$NVIM_CONFIG_DIR" 2>/dev/null)" ]; then
                rmdir "$NVIM_CONFIG_DIR"
            fi

            if [ -d "$NVIM_CONFIG_DIR" ]; then
                print_warning "NeoVim config directory already exists and is not empty: $NVIM_CONFIG_DIR"
                print_info "Skipping NeoVim config install to avoid overwriting existing files"
            else
                print_info "Installing custom NeoVim configs..."
                mkdir -p "$NVIM_CONFIG_PARENT"
                if git clone https://github.com/keennay/neovim.git "$NVIM_CONFIG_DIR"; then
                    print_info "✓ NeoVim configs installed to $NVIM_CONFIG_DIR"
                else
                    print_warning "Failed to clone NeoVim configs"
                fi
            fi
        fi
    else
        print_warning "git not found - skipping NeoVim config install"
    fi
    fi
fi

echo ""
print_info "✅ Initialization complete!"
print_info "If you installed nvm or Neovim, restart your shell or run: source ~/.bashrc"
