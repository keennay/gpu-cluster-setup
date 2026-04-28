#!/bin/bash
# Script: 02_install_coding_clis.sh
# Purpose: Install coding CLIs and their config files

set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_OWNER_USER="${SUDO_USER:-$USER}"
CONFIG_OWNER_GROUP="$(id -gn "$CONFIG_OWNER_USER" 2>/dev/null || echo "$CONFIG_OWNER_USER")"
CONFIG_HOME="$(eval echo "~$CONFIG_OWNER_USER")"
CONFIG_ROOT="$CONFIG_HOME/.config"

run_as_root() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo &> /dev/null; then
        sudo "$@"
    else
        return 1
    fi
}

ensure_config_ownership() {
    local config_root="$1"

    if [ -z "$config_root" ]; then
        print_warning "Config root not set; skipping ownership check"
        return 1
    fi

    if [ ! -d "$config_root" ]; then
        mkdir -p "$config_root" 2>/dev/null || run_as_root mkdir -p "$config_root"
    fi

    local owner group
    owner=$(stat -c '%U' "$config_root" 2>/dev/null)
    group=$(stat -c '%G' "$config_root" 2>/dev/null)

    if [ "$owner" != "$CONFIG_OWNER_USER" ] || [ "$group" != "$CONFIG_OWNER_GROUP" ]; then
        print_warning "$config_root is owned by $owner:$group; fixing ownership for $CONFIG_OWNER_USER:$CONFIG_OWNER_GROUP"
        if run_as_root chown -R "$CONFIG_OWNER_USER:$CONFIG_OWNER_GROUP" "$config_root"; then
            print_info "Ownership updated for $config_root"
        else
            print_warning "Failed to update ownership for $config_root"
            return 1
        fi
    fi

    return 0
}

set_target_ownership() {
    local target="$1"

    if [ -e "$target" ]; then
        run_as_root chown -R "$CONFIG_OWNER_USER:$CONFIG_OWNER_GROUP" "$target" 2>/dev/null || true
    fi
}

prompt_yes_no() {
    local result_var="$1"
    local prompt="$2"

    if [ "$AUTO_YES" = true ]; then
        printf -v "$result_var" "y"
    else
        read -p "$prompt" "$result_var"
    fi
}

load_nvm_node() {
    if command -v npm &> /dev/null; then
        return
    fi

    export NVM_DIR="${NVM_DIR:-$CONFIG_HOME/.nvm}"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        # shellcheck disable=SC1090
        . "$NVM_DIR/nvm.sh"
        if ! command -v npm &> /dev/null; then
            nvm use 24 >/dev/null 2>&1 || nvm use node >/dev/null 2>&1 || true
        fi
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

print_info "Coding CLI Installer"
echo ""

load_nvm_node

if ! command -v npm &> /dev/null; then
    print_error "npm not found - install Node.js first by running ./01_init.sh"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    print_error "curl not found - install basic Linux essentials first by running ./01_init.sh"
    exit 1
fi

print_info "Available coding CLIs to install:"
print_info "  1. Claude Code (@anthropic-ai/claude-code)"
print_info "  2. Claude Code Router (@musistudio/claude-code-router)"
print_info "  3. Gemini CLI (@google/gemini-cli)"
print_info "  4. OpenAI Codex (@openai/codex)"
print_info "  5. Qwen Code (@qwen-code/qwen-code)"
print_info "  6. OpenCode AI (opencode-ai)"
echo ""

prompt_yes_no INSTALL_CLIS "Install coding CLIs? (y/n): "

if [[ "$INSTALL_CLIS" =~ ^[Yy]$ ]]; then
    # Claude Code
    prompt_yes_no INSTALL_CLAUDE "  Install Claude Code? (y/n): "
    if [[ "$INSTALL_CLAUDE" =~ ^[Yy]$ ]]; then
        print_info "Installing Claude Code..."
        if curl -fsSL https://claude.ai/install.sh | bash; then
            print_info "Claude Code installed"
        else
            print_warning "Failed to install Claude Code"
        fi
    fi

    # Claude Code Router
    prompt_yes_no INSTALL_CCR "  Install Claude Code Router? (y/n): "
    if [[ "$INSTALL_CCR" =~ ^[Yy]$ ]]; then
        print_info "Installing Claude Code Router..."
        if npm install -g @musistudio/claude-code-router; then
            print_info "Claude Code Router installed"

            CONFIG_SOURCE="$SCRIPT_DIR/configs/.claude-code-router/config.json"
            CONFIG_DIR="$CONFIG_HOME/.claude-code-router"
            CONFIG_TARGET="$CONFIG_DIR/config.json"

            if [ -f "$CONFIG_SOURCE" ]; then
                print_info "Setting up Claude Code Router config..."
                mkdir -p "$CONFIG_DIR"
                if cp "$CONFIG_SOURCE" "$CONFIG_TARGET"; then
                    set_target_ownership "$CONFIG_DIR"
                    print_info "Config file copied to $CONFIG_TARGET"
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
    prompt_yes_no INSTALL_GEMINI "  Install Gemini CLI? (y/n): "
    if [[ "$INSTALL_GEMINI" =~ ^[Yy]$ ]]; then
        print_info "Installing Gemini CLI..."
        npm install -g @google/gemini-cli
        [ $? -eq 0 ] && print_info "Gemini CLI installed" || print_warning "Failed to install Gemini CLI"
    fi

    # OpenAI Codex
    prompt_yes_no INSTALL_CODEX "  Install OpenAI Codex? (y/n): "
    if [[ "$INSTALL_CODEX" =~ ^[Yy]$ ]]; then
        print_info "Installing OpenAI Codex..."
        npm install -g @openai/codex
        [ $? -eq 0 ] && print_info "OpenAI Codex installed" || print_warning "Failed to install OpenAI Codex"
    fi

    # Qwen Code
    prompt_yes_no INSTALL_QWEN "  Install Qwen Code? (y/n): "
    if [[ "$INSTALL_QWEN" =~ ^[Yy]$ ]]; then
        print_info "Installing Qwen Code..."
        npm install -g @qwen-code/qwen-code
        [ $? -eq 0 ] && print_info "Qwen Code installed" || print_warning "Failed to install Qwen Code"
    fi

    # OpenCode AI
    prompt_yes_no INSTALL_OPENCODE "  Install OpenCode AI? (y/n): "
    if [[ "$INSTALL_OPENCODE" =~ ^[Yy]$ ]]; then
        print_info "Installing OpenCode AI..."
        if curl -fsSL https://opencode.ai/install | bash; then
            print_info "OpenCode AI installed"

            OPENCODE_CONFIG_SOURCE="$SCRIPT_DIR/configs/opencode.json"

            if [ -f "$OPENCODE_CONFIG_SOURCE" ]; then
                print_info "Setting up OpenCode config..."
                if ensure_config_ownership "$CONFIG_ROOT"; then
                    OPENCODE_CONFIG_DIR="$CONFIG_ROOT/opencode"
                    OPENCODE_CONFIG_TARGET="$OPENCODE_CONFIG_DIR/opencode.json"
                    mkdir -p "$OPENCODE_CONFIG_DIR"
                    if cp "$OPENCODE_CONFIG_SOURCE" "$OPENCODE_CONFIG_TARGET"; then
                        set_target_ownership "$OPENCODE_CONFIG_DIR"
                        print_info "OpenCode config copied to $OPENCODE_CONFIG_TARGET"
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

echo ""
print_info "Coding CLI installation complete"
