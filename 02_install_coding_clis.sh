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

ensure_config_ownership() {
    local config_root="$1"

    if [ -z "$config_root" ]; then
        print_warning "Config root not set; skipping config setup"
        return 1
    fi

    if [ ! -d "$config_root" ]; then
        if ! mkdir -p "$config_root"; then
            print_warning "Failed to create $config_root without sudo; skipping config setup"
            return 1
        fi
    fi

    local owner group
    owner=$(stat -c '%U' "$config_root" 2>/dev/null)
    group=$(stat -c '%G' "$config_root" 2>/dev/null)

    if [ "$owner" != "$CONFIG_OWNER_USER" ] || [ "$group" != "$CONFIG_OWNER_GROUP" ]; then
        print_warning "$config_root is owned by $owner:$group; skipping config setup to avoid sudo"
        return 1
    fi

    if [ ! -w "$config_root" ]; then
        print_warning "$config_root is not writable; skipping config setup"
        return 1
    fi

    return 0
}

warn_on_ownership_mismatch() {
    local target="$1"

    if [ -e "$target" ]; then
        local owner group
        owner=$(stat -c '%U' "$target" 2>/dev/null)
        group=$(stat -c '%G' "$target" 2>/dev/null)

        if [ "$owner" != "$CONFIG_OWNER_USER" ] || [ "$group" != "$CONFIG_OWNER_GROUP" ]; then
            print_warning "$target is owned by $owner:$group; leaving ownership unchanged to avoid sudo"
        fi
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
    print_error "npm not found - install Node.js first by running ./01_install_dependencies.sh"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    print_error "curl not found - install basic Linux essentials first by running ./01_install_dependencies.sh"
    exit 1
fi

print_info "Available coding CLIs to install:"
print_info "  1. Claude Code (@anthropic-ai/claude-code)"
print_info "  2. Gemini CLI (@google/gemini-cli)"
print_info "  3. Grok Build (grok)"
print_info "  4. OMP Coding Agent (omp)"
print_info "  5. OpenAI Codex (@openai/codex)"
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

    # Gemini CLI
    prompt_yes_no INSTALL_GEMINI "  Install Gemini CLI? (y/n): "
    if [[ "$INSTALL_GEMINI" =~ ^[Yy]$ ]]; then
        print_info "Installing Gemini CLI..."
        npm install -g @google/gemini-cli
        [ $? -eq 0 ] && print_info "Gemini CLI installed" || print_warning "Failed to install Gemini CLI"
    fi

    # Grok Build
    prompt_yes_no INSTALL_GROK "  Install Grok Build? (y/n): "
    if [[ "$INSTALL_GROK" =~ ^[Yy]$ ]]; then
        print_info "Installing Grok Build..."
        if curl -fsSL https://x.ai/cli/install.sh | bash; then
            print_info "Grok Build installed"
        else
            print_warning "Failed to install Grok Build"
        fi
    fi

    # OMP Coding Agent
    prompt_yes_no INSTALL_OMP "  Install OMP Coding Agent? (y/n): "
    if [[ "$INSTALL_OMP" =~ ^[Yy]$ ]]; then
        print_info "Installing OMP Coding Agent..."
        if curl -fsSL https://omp.sh/install | sh; then
            print_info "OMP Coding Agent installed"
        else
            print_warning "Failed to install OMP Coding Agent"
        fi
    fi

    # OpenAI Codex
    prompt_yes_no INSTALL_CODEX "  Install OpenAI Codex? (y/n): "
    if [[ "$INSTALL_CODEX" =~ ^[Yy]$ ]]; then
        print_info "Installing OpenAI Codex..."
        if curl -fsSL https://chatgpt.com/codex/install.sh | sh; then
            print_info "OpenAI Codex installed"
	else
	    print_warning "Failed to install OpenAI Codex"
	fi
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
                        warn_on_ownership_mismatch "$OPENCODE_CONFIG_DIR"
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
