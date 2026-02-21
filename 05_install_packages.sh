#!/bin/bash

# Script: 05_install_packages.sh
# Purpose: Provide environment placeholders without installing packages.
# Usage: ./05_install_packages.sh [--env ENV_NAME]

if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_command() { echo -e "${BLUE}[RUN]${NC} $1"; }

ACTION_TAKEN=false

ENV_TYPES=(
  "deepseek-lmdeploy"
  "deepseek-sglang"
  "deepseek-vllm"
  "glm-sglang"
  "glm-transformers"
  "glm-vllm"
  "gpt-oss-transformers"
  "gpt-oss-vllm"
  "kimi-ktransformers"
  "kimi-sglang"
  "kimi-vllm"
  "minimax-ktransformers"
  "minimax-sglang"
  "minimax-transformers"
  "minimax-vllm"
  "qwen3-sglang"
  "qwen3-transformers"
  "qwen3-vllm"
)

declare -A ENV_DESCRIPTIONS=(
  ["deepseek-lmdeploy"]="DeepSeek-V3.X/R1/OCR (LMDeploy)"
  ["deepseek-sglang"]="DeepSeek-V3.X/R1/OCR (SGLang)"
  ["deepseek-vllm"]="DeepSeek-V3.X/R1/OCR (vLLM)"
  ["glm-sglang"]="GLM 4.X (SGLang)"
  ["glm-transformers"]="GLM 4.X (Transformers)"
  ["glm-vllm"]="GLM 4.X (vLLM)"
  ["gpt-oss-transformers"]="gpt-oss (Transformers)"
  ["gpt-oss-vllm"]="gpt-oss (vLLM)"
  ["kimi-ktransformers"]="Kimi K2.X (KTransformers)"
  ["kimi-sglang"]="Kimi K2.X (SGLang)"
  ["kimi-vllm"]="Kimi K2.X (vLLM)"
  ["minimax-ktransformers"]="MiniMax-M2.X (KTransformers)"
  ["minimax-sglang"]="MiniMax-M2.X (SGLang)"
  ["minimax-transformers"]="MiniMax-M2.X (Transformers)"
  ["minimax-vllm"]="MiniMax-M2.X (vLLM)"
  ["qwen3-sglang"]="Qwen3 (SGLang)"
  ["qwen3-transformers"]="Qwen3 (Transformers)"
  ["qwen3-vllm"]="Qwen3 (vLLM)"
)

resolve_env_type() {
    case "$1" in
        1|deepseek_lmdeploy|deepseek-lmdeploy)
            echo "deepseek-lmdeploy"
            ;;
        2|deepseek_sglang|deepseek-sglang)
            echo "deepseek-sglang"
            ;;
        3|deepseek_vllm|deepseek-vllm)
            echo "deepseek-vllm"
            ;;
        4|glm_sglang|glm-sglang)
            echo "glm-sglang"
            ;;
        5|glm_transformers|glm-transformers)
            echo "glm-transformers"
            ;;
        6|glm_vllm|glm-vllm)
            echo "glm-vllm"
            ;;
        7|gptoss_transformers|gpt-oss_transformers|gptoss-transformers|gpt-oss-transformers)
            echo "gpt-oss-transformers"
            ;;
        8|gptoss_vllm|gpt-oss_vllm|vllm_gptoss|gptoss-vllm|gpt-oss-vllm)
            echo "gpt-oss-vllm"
            ;;
        9|kimi_ktransformers|kimi-ktransformers)
            echo "kimi-ktransformers"
            ;;
        10|kimi_sglang|kimi-sglang)
            echo "kimi-sglang"
            ;;
        11|kimi_vllm|kimi-vllm)
            echo "kimi-vllm"
            ;;
        12|minimax_ktransformers|minimax-ktransformers)
            echo "minimax-ktransformers"
            ;;
        13|minimax_sglang|minimax-sglang)
            echo "minimax-sglang"
            ;;
        14|minimax_transformers|minimax-transformers)
            echo "minimax-transformers"
            ;;
        15|minimax_vllm|minimax-vllm)
            echo "minimax-vllm"
            ;;
        16|qwen3_sglang|qwen3-sglang)
            echo "qwen3-sglang"
            ;;
        17|qwen3_transformers|qwen3-transformers)
            echo "qwen3-transformers"
            ;;
        18|qwen3_vllm|qwen3-vllm)
            echo "qwen3-vllm"
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                return 1
            fi
            return 1
            ;;
    esac
}

print_env_options() {
    print_info "Available environments from 04_setup_env.sh:"
    local index=1
    for key in "${ENV_TYPES[@]}"; do
        printf "  %2d) %s (%s)\n" "$index" "${ENV_DESCRIPTIONS[$key]}" "$key"
        index=$((index + 1))
    done
}

normalize_env_name() {
    local raw="$1"
    raw="${raw%/}"
    raw=$(basename "$raw")
    raw="${raw%_env}"
    echo "$raw"
}

detect_environment() {
    local virtual_env="${VIRTUAL_ENV:-}"
    if [ -z "$virtual_env" ]; then
        return 1
    fi

    local base
    base=$(normalize_env_name "$virtual_env")

    if resolved=$(resolve_env_type "$base"); then
        echo "$resolved"
        return 0
    fi

    for key in "${ENV_TYPES[@]}"; do
        if [[ "$virtual_env" == *"/${key}_env"* ]] || [[ "$virtual_env" == *"/$key"* ]]; then
            echo "$key"
            return 0
        fi
    done

    return 1
}

handle_environment() {
    local env="$1"
    local desc="${ENV_DESCRIPTIONS[$env]}"

    if [ -z "$desc" ]; then
        desc="$env"
    fi

    print_info "Environment: $desc"
}

run_command() {
    local cmd=("$@")
    print_command "$(printf '%q ' "${cmd[@]}")"
    if "${cmd[@]}"; then
        return 0
    fi
    return 1
}

run_uv_install() {
    if ! command -v uv >/dev/null 2>&1; then
        print_error "uv is not available on PATH."
        return 1
    fi

    local cmd=(uv pip install)
    cmd+=("$@")

    if run_command "${cmd[@]}"; then
        print_info "Packages installed successfully."
        return 0
    fi

    print_error "Package installation failed."
    return 1
}

install_glm_sglang() {
    print_info "Installing packages for GLM 4.X (SGLang)..."
    
    run_uv_install sglang==0.3.2.dev9039+pr-17247.g90c446848 --extra-index-url https://sgl-project.github.io/whl/pr/
    run_uv_install git+https://github.com/huggingface/transformers.git@76732b4e7120808ff989edbd16401f61fa6a0afa
}

install_glm_transformers() {
    print_info "Installing packages for GLM 4.X (Transformers)..."

    run_uv_install git+https://github.com/huggingface/transformers.git@76732b4e7120808ff989edbd16401f61fa6a0afa
}

install_glm_vllm() {
    print_info "Installing packages for GLM 4.X (vLLM)..."
    local packages=(
        "git+https://github.com/huggingface/transformers.git"
        "pre-commit>=4.2.0"
        "accelerate>=1.10.1"
    )

    run_uv_install -U vllm --pre --index-url https://pypi.org/simple \
        --extra-index-url https://wheels.vllm.ai/nightly || return 1
    run_uv_install "${packages[@]}"
}

install_deepseek_lmdeploy() {
    print_info "Installing LMDeploy for DeepSeek..."
    local target_dir=""
    if [ -n "${LMDEPLOY_DIR:-}" ]; then
        target_dir="$LMDEPLOY_DIR"
    elif [ -n "${VIRTUAL_ENV:-}" ]; then
        target_dir="$VIRTUAL_ENV/lmdeploy"
    else
        target_dir="$HOME/lmdeploy"
    fi

    if [ -d "$target_dir/.git" ]; then
        print_info "Updating existing repository at $target_dir"
        run_command git -C "$target_dir" fetch origin || return 1
        run_command git -C "$target_dir" checkout support-dsv3 || return 1
        run_command git -C "$target_dir" pull --ff-only || return 1
    else
        local parent_dir
        parent_dir=$(dirname "$target_dir")
        if [ ! -d "$parent_dir" ]; then
            run_command mkdir -p "$parent_dir" || return 1
        fi
        run_command git clone -b support-dsv3 https://github.com/InternLM/lmdeploy.git "$target_dir" || return 1
    fi

    run_uv_install -e "$target_dir"
}

install_deepseek_sglang() {
    print_info "Installing SGLang for DeepSeek..."
    run_uv_install "sglang[all]>=0.5.3rc0"
}

install_deepseek_vllm() {
    print_info "Installing vLLM for DeepSeek..."
    run_uv_install vllm
}

install_gptoss_transformers() {
    print_info "Installing Transformers stack for gpt-oss..."
    run_uv_install -U transformers accelerate torch triton==3.4 kernels
}

install_gptoss_vllm() {
    print_info "Installing vLLM GPT-OSS build..."
    run_uv_install --pre vllm==0.10.1+gptoss \
        --extra-index-url https://wheels.vllm.ai/gpt-oss/ \
        --extra-index-url https://download.pytorch.org/whl/nightly/cu128 \
        --index-strategy unsafe-best-match
}

install_kimi_ktransformers() {
    print_info "Installing KTransformers for Kimi K2.X..."

    local ktransformers_dir=""
    if [ -n "${KTRANSFORMERS_DIR:-}" ]; then
        ktransformers_dir="$KTRANSFORMERS_DIR"
    elif [ -n "${VIRTUAL_ENV:-}" ]; then
        ktransformers_dir="$VIRTUAL_ENV/ktransformers"
    else
        ktransformers_dir="$HOME/ktransformers"
    fi

    if [ ! -d "$ktransformers_dir/.git" ]; then
	local parent_dir
        parent_dir=$(dirname "$ktransformers_dir")
        if [ ! -d "$parent_dir" ]; then
            run_command mkdir -p "$parent_dir" || return 1
        fi
        run_command git clone https://github.com/kvcache-ai/ktransformers.git "$ktransformers_dir" || return 1
    fi

    run_command git -C "$ktransformers_dir" submodule update --init --recursive || return 1

    if [ -d "$ktransformers_dir/kt-kernel" ]; then
        # kt-kernel install script calls python -m pip; ensure pip exists in uv venvs.
        run_uv_install pip || return 1
        run_command bash -c "cd \"$ktransformers_dir/kt-kernel\" && ./install.sh" || return 1
    else
        print_warning "kt-kernel directory not found at $ktransformers_dir/kt-kernel"
        return 1
    fi

    print_info "Installing SGLang for Kimi K2.X..."

    local sglang_dir=""
    if [ -n "${SGLANG_DIR:-}" ]; then
        sglang_dir="$SGLANG_DIR"
    elif [ -n "${VIRTUAL_ENV:-}" ]; then
        sglang_dir="$VIRTUAL_ENV/sglang"
    else
        sglang_dir="$HOME/sglang"
    fi

    if [ ! -d "$sglang_dir/.git" ]; then
        local parent_dir
        parent_dir=$(dirname "$sglang_dir")
        if [ ! -d "$parent_dir" ]; then
            run_command mkdir -p "$parent_dir" || return 1
        fi
        run_command git clone https://github.com/kvcache-ai/sglang.git "$sglang_dir" || return 1
    fi

    run_uv_install -e "$sglang_dir/python[all]" || return 1
    run_uv_install nvidia-cudnn-cu12==9.16.0.29 || return 1
}
install_kimi_sglang() {
    print_info "Installing SGLang for Kimi K2.X..."
    run_uv_install "sglang @ git+https://github.com/sgl-project/sglang.git#subdirectory=python"
    run_uv_install remote_pdb
    run_uv_install imageio
    run_uv_install diffusers
    run_uv_install addict
    run_uv_install cache_dit
    run_uv_install nvidia-cudnn-cu12==9.16.0.29
}

install_kimi_vllm() {
    print_info "Installing vLLM for Kimi K2.X..."
    run_uv_install -U vllm --torch-backend=auto --extra-index-url https://wheels.vllm.ai/nightly
}

install_minimax_ktransformers() {
    print_info "Installing KTransformers for MiniMax-M2.X..."

    local target_dir=""
    if [ -n "${KTRANSFORMERS_DIR:-}" ]; then
        target_dir="$KTRANSFORMERS_DIR"
    elif [ -n "${VIRTUAL_ENV:-}" ]; then
        target_dir="$VIRTUAL_ENV/ktransformers"
    else
        target_dir="$HOME/ktransformers"
    fi

    if [ -d "$target_dir/.git" ]; then
        print_info "Updating existing repository at $target_dir"
        run_command git -C "$target_dir" fetch origin || return 1
        run_command git -C "$target_dir" pull --ff-only || return 1
    else
        local parent_dir
        parent_dir=$(dirname "$target_dir")
        if [ ! -d "$parent_dir" ]; then
            run_command mkdir -p "$parent_dir" || return 1
        fi
        run_command git clone https://github.com/kvcache-ai/sglang.git "$target_dir" || return 1
    fi

    run_uv_install -e "$target_dir/python[all]"
}

install_minimax_sglang() {
    print_info "Installing SGLang for MiniMax-M2.X..."

    local target_dir=""
    if [ -n "${SGLANG_DIR:-}" ]; then
        target_dir="$SGLANG_DIR"
    elif [ -n "${VIRTUAL_ENV:-}" ]; then
        target_dir="$VIRTUAL_ENV/sglang"
    else
        target_dir="$HOME/sglang"
    fi

    if [ -d "$target_dir/.git" ]; then
        print_info "Updating existing repository at $target_dir"
        run_command git -C "$target_dir" fetch origin || return 1
        run_command git -C "$target_dir" pull --ff-only || return 1
    else
        local parent_dir
        parent_dir=$(dirname "$target_dir")
        if [ ! -d "$parent_dir" ]; then
            run_command mkdir -p "$parent_dir" || return 1
        fi
        run_command git clone https://github.com/sgl-project/sglang "$target_dir" || return 1
    fi

    run_uv_install -e "$target_dir/python" --prerelease=allow
}

install_minimax_transformers() {
    print_info "Installing Transformers for MiniMax-M2.X..."
    run_uv_install "transformers==4.57.1" "torch" "accelerate" "--torch-backend=auto"
}

install_minimax_vllm() {
    print_info "Installing vLLM for MiniMax-M2.X..."
    run_uv_install -U vllm --extra-index-url https://wheels.vllm.ai/nightly
}

install_qwen3_sglang() {
    print_info "Installing SGLang for Qwen3..."
    run_uv_install "git+https://github.com/sgl-project/sglang.git#subdirectory=python&egg=sglang[all]"
    run_uv_install nvidia-cudnn-cu12==9.16.0.29
}

install_qwen3_transformers() {
    print_info "Installing Transformers stack for Qwen3..."
    run_uv_install "transformers>=4.51.0" "torch>=2.6"
}

install_qwen3_vllm() {
    print_info "Installing vLLM for Qwen3..."
    run_uv_install vllm --torch-backend=auto --extra-index-url https://wheels.vllm.ai/nightly
}

perform_environment_action() {
    ACTION_TAKEN=false

    case "$1" in
        deepseek-lmdeploy)
            install_deepseek_lmdeploy || return 1
            ACTION_TAKEN=true
            ;;
        deepseek-sglang)
            install_deepseek_sglang || return 1
            ACTION_TAKEN=true
            ;;
        deepseek-vllm)
            install_deepseek_vllm || return 1
            ACTION_TAKEN=true
            ;;
        glm-sglang)
            install_glm_sglang || return 1
            ACTION_TAKEN=true
            ;;
        glm-transformers)
            install_glm_transformers || return 1
            ACTION_TAKEN=true
            ;;
        glm-vllm)
            install_glm_vllm || return 1
            ACTION_TAKEN=true
            ;;
        gpt-oss-transformers)
            install_gptoss_transformers || return 1
            ACTION_TAKEN=true
            ;;
        gpt-oss-vllm)
            install_gptoss_vllm || return 1
            ACTION_TAKEN=true
            ;;
        kimi-ktransformers)
            install_kimi_ktransformers || return 1
            ACTION_TAKEN=true
            ;;
        kimi-sglang)
            install_kimi_sglang || return 1
            ACTION_TAKEN=true
            ;;
        kimi-vllm)
            install_kimi_vllm || return 1
            ACTION_TAKEN=true
            ;;
        minimax-ktransformers)
            install_minimax_ktransformers || return 1
            ACTION_TAKEN=true
            ;;
        minimax-sglang)
            install_minimax_sglang || return 1
            ACTION_TAKEN=true
            ;;
        minimax-transformers)
            install_minimax_transformers || return 1
            ACTION_TAKEN=true
            ;;
        minimax-vllm)
            install_minimax_vllm || return 1
            ACTION_TAKEN=true
            ;;
        qwen3-sglang)
            install_qwen3_sglang || return 1
            ACTION_TAKEN=true
            ;;
        qwen3-transformers)
            install_qwen3_transformers || return 1
            ACTION_TAKEN=true
            ;;
        qwen3-vllm)
            install_qwen3_vllm || return 1
            ACTION_TAKEN=true
            ;;
        *)
            print_info "No automated package actions configured for this environment."
            ;;
    esac

    return 0
}

main() {
    local override=""
    local show_help=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --env)
                if [[ $# -lt 2 ]]; then
                    print_error "Missing value for --env"
                    return 1
                fi
                override="$2"
                shift 2
                ;;
            -y|--yes|--auto)
                print_warning "Flag '$1' has no effect; no installations occur in this script."
                shift
                ;;
            -h|--help)
                show_help=true
                shift
                ;;
            *)
                print_warning "Ignoring unknown argument: $1"
                shift
                ;;
        esac
    done

    if [ "$show_help" = true ]; then
        echo "Usage: ./05_install_packages.sh [--env ENV_NAME]"
        echo
        print_env_options
        return 0
    fi

    local env_type=""

    if [ -n "$override" ]; then
        if env_type=$(resolve_env_type "$override"); then
            print_info "Environment override provided: $env_type"
        else
            print_warning "Environment override '$override' is not managed by this script."
            print_info "Nothing to configure in 05_install_packages.sh."
            return 0
        fi
    else
        if ! env_type=$(detect_environment); then
            if [ -n "${VIRTUAL_ENV:-}" ]; then
                print_warning "Active virtual environment '$VIRTUAL_ENV' is not managed by this script."
            else
                print_info "No active virtual environment detected."
            fi
            print_info "Nothing to configure in 05_install_packages.sh."
            return 0
        fi
    fi

    if [ -n "${VIRTUAL_ENV:-}" ]; then
        print_info "Virtual environment: $VIRTUAL_ENV"
    fi

    echo
    handle_environment "$env_type"
    echo

    if ! perform_environment_action "$env_type"; then
        print_error "Environment handling failed."
        return 1
    fi

    if [ "$ACTION_TAKEN" = false ]; then
        print_info "Nothing to install. Customize this script if you need per-environment actions."
    fi
}

main "$@"
exit $?
