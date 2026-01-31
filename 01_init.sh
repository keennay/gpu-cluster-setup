#!/bin/bash
# Script: 01_init.sh
# Purpose: Initialize environment with Node.js and various coding CLIs

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
        else
            PKG_INSTALL_CMD="${sudo_prefix}yum install -y"
            PKG_UPDATE_CMD="${sudo_prefix}yum makecache"
            PKG_UPGRADE_CMD="${sudo_prefix}yum upgrade -y"
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
    BASIC_LINUX_ESSENTIALS=(curl wget less vim nano tmux git git-lfs htop nvtop ripgrep)
else
    BASIC_LINUX_ESSENTIALS=(curl wget less vim-enhanced nano tmux git git-lfs htop nvtop ripgrep)
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
if [ "$AUTO_YES" = true ]; then
    INSTALL_NVM="y"
else
    read -p "Install nvm (Node Version Manager)? (y/n): " INSTALL_NVM
fi

if [[ "$INSTALL_NVM" =~ ^[Yy]$ ]]; then
    print_info "Checking for existing nvm installation..."
    if [ -d "$HOME/.nvm" ]; then
        print_info "✓ nvm is already installed"
    else
        print_info "Downloading and installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
        if [ $? -ne 0 ]; then
            print_error "Failed to install nvm"
            exit 1
        fi
        print_info "✓ nvm installed"
    fi
    
    # Load nvm for current session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
else
    print_info "Skipped nvm installation"
fi

echo ""

# Install Node.js 22
if [[ "$INSTALL_NVM" =~ ^[Yy]$ ]]; then
    if [ "$AUTO_YES" = true ]; then
        INSTALL_NODE="y"
    else
        read -p "Install Node.js 22? (y/n): " INSTALL_NODE
    fi
    
    if [[ "$INSTALL_NODE" =~ ^[Yy]$ ]]; then
        print_info "Installing Node.js 22..."
        nvm install 22
        if [ $? -ne 0 ]; then
            print_error "Failed to install Node.js 22"
            exit 1
        fi
        nvm use 22
        print_info "✓ Node.js installed"
        
        # Verify installation
        NODE_VERSION=$(node -v 2>/dev/null)
        NPM_VERSION=$(npm -v 2>/dev/null)
        print_info "Node.js version: $NODE_VERSION"
        print_info "npm version: $NPM_VERSION"
    else
        print_info "Skipped Node.js installation"
    fi
fi

echo ""

# Install coding CLIs
if command -v npm &> /dev/null; then
    print_info "Available coding CLIs to install:"
    print_info "  1. Claude Code (@anthropic-ai/claude-code)"
    print_info "  2. Claude Code Router (@musistudio/claude-code-router)"
    print_info "  3. Gemini CLI (@google/gemini-cli)"
    print_info "  4. OpenAI Codex (@openai/codex)"
    print_info "  5. Qwen Code (@qwen-code/qwen-code)"
    print_info "  6. OpenCode AI (opencode-ai)"
    echo ""
    
    if [ "$AUTO_YES" = true ]; then
        INSTALL_CLIS="y"
    else
        read -p "Install coding CLIs? (y/n): " INSTALL_CLIS
    fi
    
    if [[ "$INSTALL_CLIS" =~ ^[Yy]$ ]]; then
        # Claude Code
        if [ "$AUTO_YES" = true ]; then
            INSTALL_CLAUDE="y"
        else
            read -p "  Install Claude Code? (y/n): " INSTALL_CLAUDE
        fi
        if [[ "$INSTALL_CLAUDE" =~ ^[Yy]$ ]]; then
            print_info "Installing Claude Code..."
            npm install -g @anthropic-ai/claude-code
            [ $? -eq 0 ] && print_info "✓ Claude Code installed" || print_warning "Failed to install Claude Code"
        fi

	#Claude Code Router
        if [ "$AUTO_YES" = true ]; then
            INSTALL_CCR="y"
        else
            read -p "  Install Claude Code Router? (y/n): " INSTALL_CCR
        fi
        if [[ "$INSTALL_CCR" =~ ^[Yy]$ ]]; then
            print_info "Installing Claude Code Router..."
            npm install -g @musistudio/claude-code-router
            if [ $? -eq 0 ]; then
                print_info "✓ Claude Code Router installed"
                
                # Copy config file to ~/.claude-code-router/
                CONFIG_SOURCE="$(dirname "$0")/configs/.claude-code-router/config.json"
                CONFIG_DIR="$HOME/.claude-code-router"
                CONFIG_TARGET="$CONFIG_DIR/config.json"
                
                if [ -f "$CONFIG_SOURCE" ]; then
                    print_info "Setting up Claude Code Router config..."
                    
                    # Create directory if it doesn't exist
                    mkdir -p "$CONFIG_DIR"
                    
                    # Copy config file
                    cp "$CONFIG_SOURCE" "$CONFIG_TARGET"
                    if [ $? -eq 0 ]; then
                        print_info "✓ Config file copied to $CONFIG_TARGET"
                    else
                        print_warning "Failed to copy config file"
                    fi
                else
                    print_warning "Config file not found at $CONFIG_SOURCE"
                fi
            else
                print_warning "Failed to install Claude Code Router"
            fi
        fi
        
        # Gemini CLI
        if [ "$AUTO_YES" = true ]; then
            INSTALL_GEMINI="y"
        else
            read -p "  Install Gemini CLI? (y/n): " INSTALL_GEMINI
        fi
        if [[ "$INSTALL_GEMINI" =~ ^[Yy]$ ]]; then
            print_info "Installing Gemini CLI..."
            npm install -g @google/gemini-cli
            [ $? -eq 0 ] && print_info "✓ Gemini CLI installed" || print_warning "Failed to install Gemini CLI"
        fi
        
        # OpenAI Codex
        if [ "$AUTO_YES" = true ]; then
            INSTALL_CODEX="y"
        else
            read -p "  Install OpenAI Codex? (y/n): " INSTALL_CODEX
        fi
        if [[ "$INSTALL_CODEX" =~ ^[Yy]$ ]]; then
            print_info "Installing OpenAI Codex..."
            npm install -g @openai/codex
            [ $? -eq 0 ] && print_info "✓ OpenAI Codex installed" || print_warning "Failed to install OpenAI Codex"
        fi
        
        # Qwen Code
        if [ "$AUTO_YES" = true ]; then
            INSTALL_QWEN="y"
        else
            read -p "  Install Qwen Code? (y/n): " INSTALL_QWEN
        fi
        if [[ "$INSTALL_QWEN" =~ ^[Yy]$ ]]; then
            print_info "Installing Qwen Code..."
            npm install -g @qwen-code/qwen-code
            [ $? -eq 0 ] && print_info "✓ Qwen Code installed" || print_warning "Failed to install Qwen Code"
        fi
        
        # OpenCode AI
        if [ "$AUTO_YES" = true ]; then
            INSTALL_OPENCODE="y"
        else
            read -p "  Install OpenCode AI? (y/n): " INSTALL_OPENCODE
        fi
        if [[ "$INSTALL_OPENCODE" =~ ^[Yy]$ ]]; then
            print_info "Installing OpenCode AI..."
            npm install -g opencode-ai@latest
            if [ $? -eq 0 ]; then
                print_info "✓ OpenCode AI installed"

                # Set up OpenCode config to avoid runtime directory creation issues
                OPENCODE_CONFIG_SOURCE="$(dirname "$0")/configs/opencode.json"

                if [ -f "$OPENCODE_CONFIG_SOURCE" ]; then
                    print_info "Setting up OpenCode config..."
                    if ensure_config_ownership "$CONFIG_ROOT"; then
                        OPENCODE_CONFIG_DIR="$CONFIG_ROOT/opencode"
                        OPENCODE_CONFIG_TARGET="$OPENCODE_CONFIG_DIR/opencode.json"
                        mkdir -p "$OPENCODE_CONFIG_DIR"
                        if cp "$OPENCODE_CONFIG_SOURCE" "$OPENCODE_CONFIG_TARGET"; then
                            print_info "✓ OpenCode config copied to $OPENCODE_CONFIG_TARGET"
                        else
                            print_warning "Failed to copy OpenCode config"
                        fi
                    else
                        print_warning "Skipping OpenCode config setup due to ownership issues"
                    fi
                else
                    print_warning "OpenCode config not found at $OPENCODE_CONFIG_SOURCE"
                fi
            else
                print_warning "Failed to install OpenCode AI"
            fi
        fi
    else
        print_info "Skipped CLI installations"
    fi
else
    print_warning "npm not found - skipping CLI installations"
    print_info "Install Node.js first to install coding CLIs"
fi

NVIM_AVAILABLE=false

# Install latest Neovim (downloaded from GitHub releases)
if [ "$AUTO_YES" = true ]; then
    INSTALL_NVIM_LATEST="y"
else
    read -p "Install latest Neovim (download from GitHub releases)? (y/n): " INSTALL_NVIM_LATEST
fi

if [[ "$INSTALL_NVIM_LATEST" =~ ^[Yy]$ ]]; then
    if ! command -v tar &> /dev/null; then
        print_warning "tar not found - skipping Neovim install"
    elif ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        print_warning "curl or wget not found - skipping Neovim install"
    else
        print_info "Installing latest Neovim..."
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
    read -p "Alias vi and vim to Neovim in $CONFIG_HOME/.bashrc? (y/n): " ALIAS_NVIM

    if [[ "$ALIAS_NVIM" =~ ^[Yy]$ ]]; then
        BASHRC_PATH="$CONFIG_HOME/.bashrc"

        if [ ! -f "$BASHRC_PATH" ]; then
            if ! touch "$BASHRC_PATH" 2>/dev/null; then
                sudo touch "$BASHRC_PATH"
                sudo chown "$CONFIG_OWNER_USER:$CONFIG_OWNER_GROUP" "$BASHRC_PATH"
            fi
        fi

        # Remove previous block and any existing vi/vim alias lines
        if ! sed -i '/# Neovim aliases (added by 01_init.sh)/,/^# End Neovim aliases/d' "$BASHRC_PATH" 2>/dev/null; then
            sudo sed -i '/# Neovim aliases (added by 01_init.sh)/,/^# End Neovim aliases/d' "$BASHRC_PATH"
            sudo chown "$CONFIG_OWNER_USER:$CONFIG_OWNER_GROUP" "$BASHRC_PATH"
        fi
        if ! sed -i '/^alias vi=/d; /^alias vim=/d' "$BASHRC_PATH" 2>/dev/null; then
            sudo sed -i '/^alias vi=/d; /^alias vim=/d' "$BASHRC_PATH"
            sudo chown "$CONFIG_OWNER_USER:$CONFIG_OWNER_GROUP" "$BASHRC_PATH"
        fi

        if [ -w "$BASHRC_PATH" ]; then
            cat <<'EOF' >> "$BASHRC_PATH"
# Neovim aliases (added by 01_init.sh)
alias vi='nvim'
alias vim='nvim'
# End Neovim aliases
EOF
        else
            cat <<'EOF' | sudo tee -a "$BASHRC_PATH" > /dev/null
# Neovim aliases (added by 01_init.sh)
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

# NeoVim config install (only prompt if installed here; always prompt regardless of AUTO_YES)
if [ "$NVIM_AVAILABLE" = true ]; then
    read -p "Install NeoVim configs provided by the author of this script? (y/n): " INSTALL_NVIM_CONFIG
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
