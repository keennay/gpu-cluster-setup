#!/bin/bash

# Script: 06_install_packages.sh
# Purpose: Provide environment placeholders without installing packages.
# Usage: ./06_install_packages.sh [--env ENV_NAME]

if [ -f "$HOME/.bashrc" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.bashrc"
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
  "deepseek-ktransformers"
  "deepseek-lmdeploy"
  "deepseek-sglang"
  "deepseek-vllm"
  "gemma-sglang"
  "gemma-vllm"
  "glm-ktransformers"
  "glm-sglang"
  "glm-transformers"
  "glm-vllm"
  "gpt-oss-transformers"
  "gpt-oss-vllm"
  "kimi-ktransformers"
  "kimi-sglang"
  "kimi-vllm"
  "ling-sglang"
  "ling-transformers"
  "ling-vllm"
  "minimax-ktransformers"
  "minimax-sglang"
  "minimax-transformers"
  "minimax-vllm"
  "nemotron-sglang"
  "nemotron-trtllm"
  "nemotron-vllm"
  "qwen3-ktransformers"
  "qwen3-sglang"
  "qwen3-transformers"
  "qwen3-vllm"
)

declare -A ENV_DESCRIPTIONS=(
  ["deepseek-ktransformers"]="DeepSeek-V3/V4/R1/OCR (KTransformers)"
  ["deepseek-lmdeploy"]="DeepSeek-V3/V4/R1/OCR (LMDeploy)"
  ["deepseek-sglang"]="DeepSeek-V3/V4/R1/OCR (SGLang)"
  ["deepseek-vllm"]="DeepSeek-V3/V4/R1/OCR (vLLM)"
  ["gemma-sglang"]="Gemma-4 (SGLang)"
  ["gemma-vllm"]="Gemma-4 (vLLM)"
  ["glm-ktransformers"]="GLM-4/5 (KTransformers)"
  ["glm-sglang"]="GLM-4/5 (SGLang)"
  ["glm-transformers"]="GLM-4/5 (Transformers)"
  ["glm-vllm"]="GLM-4/5 (vLLM)"
  ["gpt-oss-transformers"]="gpt-oss (Transformers)"
  ["gpt-oss-vllm"]="gpt-oss (vLLM)"
  ["kimi-ktransformers"]="Kimi K2.X (KTransformers)"
  ["kimi-sglang"]="Kimi K2.X (SGLang)"
  ["kimi-vllm"]="Kimi K2.X (vLLM)"
  ["ling-sglang"]="Ling-2.6 (SGLang)"
  ["ling-transformers"]="Ling-2.6 (Transformers)"
  ["ling-vllm"]="Ling-2.6 (vLLM)"
  ["minimax-ktransformers"]="MiniMax-M2.X (KTransformers)"
  ["minimax-sglang"]="MiniMax-M2.X (SGLang)"
  ["minimax-transformers"]="MiniMax-M2.X (Transformers)"
  ["minimax-vllm"]="MiniMax-M2.X (vLLM)"
  ["nemotron-sglang"]="Nemotron-3 (SGLang)"
  ["nemotron-trtllm"]="Nemotron-3 (TRT-LLM)"
  ["nemotron-vllm"]="Nemotron-3 (vLLM)"
  ["qwen3-ktransformers"]="Qwen3 (KTransformers)"
  ["qwen3-sglang"]="Qwen3 (SGLang)"
  ["qwen3-transformers"]="Qwen3 (Transformers)"
  ["qwen3-vllm"]="Qwen3 (vLLM)"
)

resolve_env_type() {
    local input="${1#env_}"

    case "$input" in
        1|deepseek_ktransformers|deepseek-ktransformers)
            echo "deepseek-ktransformers"
            ;;
        2|deepseek_lmdeploy|deepseek-lmdeploy)
            echo "deepseek-lmdeploy"
            ;;
        3|deepseek_sglang|deepseek-sglang)
            echo "deepseek-sglang"
            ;;
        4|deepseek_vllm|deepseek-vllm)
            echo "deepseek-vllm"
            ;;
        5|gemma_sglang|gemma-sglang|gemma4_sglang|gemma4-sglang|gemma_4_sglang|gemma-4-sglang)
            echo "gemma-sglang"
            ;;
        6|gemma_vllm|gemma-vllm|gemma4_vllm|gemma4-vllm|gemma_4_vllm|gemma-4-vllm)
            echo "gemma-vllm"
            ;;
        7|glm_ktransformers|glm-ktransformers|glm45-ktransformers|glm_4_5_ktransformers|glm-4.5-ktransformers)
            echo "glm-ktransformers"
            ;;
        8|glm_sglang|glm-sglang|glm45-sglang)
            echo "glm-sglang"
            ;;
        9|glm_transformers|glm-transformers)
            echo "glm-transformers"
            ;;
        10|glm_vllm|glm-vllm)
            echo "glm-vllm"
            ;;
        11|gptoss_transformers|gpt-oss_transformers|gptoss-transformers|gpt-oss-transformers)
            echo "gpt-oss-transformers"
            ;;
        12|gptoss_vllm|gpt-oss_vllm|vllm_gptoss|gptoss-vllm|gpt-oss-vllm)
            echo "gpt-oss-vllm"
            ;;
        13|kimi_ktransformers|kimi-ktransformers)
            echo "kimi-ktransformers"
            ;;
        14|kimi_sglang|kimi-sglang)
            echo "kimi-sglang"
            ;;
        15|kimi_vllm|kimi-vllm)
            echo "kimi-vllm"
            ;;
        16|ling_sglang|ling-sglang|ling26_sglang|ling26-sglang|ling_2_6_sglang|ling-2.6-sglang)
            echo "ling-sglang"
            ;;
        17|ling_transformers|ling-transformers|ling26_transformers|ling26-transformers|ling_2_6_transformers|ling-2.6-transformers)
            echo "ling-transformers"
            ;;
        18|ling_vllm|ling-vllm|ling26_vllm|ling26-vllm|ling_2_6_vllm|ling-2.6-vllm)
            echo "ling-vllm"
            ;;
        19|minimax_ktransformers|minimax-ktransformers)
            echo "minimax-ktransformers"
            ;;
        20|minimax_sglang|minimax-sglang)
            echo "minimax-sglang"
            ;;
        21|minimax_transformers|minimax-transformers)
            echo "minimax-transformers"
            ;;
        22|minimax_vllm|minimax-vllm)
            echo "minimax-vllm"
            ;;
        23|nemotron_sglang|nemotron-sglang)
            echo "nemotron-sglang"
            ;;
        24|nemotron_trtllm|nemotron-trtllm|nemotron_trt_llm|nemotron-trt-llm)
            echo "nemotron-trtllm"
            ;;
        25|nemotron_vllm|nemotron-vllm)
            echo "nemotron-vllm"
            ;;
        26|qwen3_ktransformers|qwen3-ktransformers)
            echo "qwen3-ktransformers"
            ;;
        27|qwen3_sglang|qwen3-sglang)
            echo "qwen3-sglang"
            ;;
        28|qwen3_transformers|qwen3-transformers)
            echo "qwen3-transformers"
            ;;
        29|qwen3_vllm|qwen3-vllm)
            echo "qwen3-vllm"
            ;;
        30|custom|custom_uv|custom-uv|env_custom_uv)
            echo "custom_uv"
            ;;
        31|custom_pip|custom-pip|env_custom_pip)
            echo "custom_pip"
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
    print_info "Available environments from 05_setup_env.sh:"
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
    raw="${raw#env_}"
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
        if [[ "$virtual_env" == *"/env_${key}"* ]] || [[ "$virtual_env" == *"/$key"* ]]; then
            echo "$key"
            return 0
        fi
    done

    return 1
}

ensure_active_environment_matches() {
    local expected="$1"

    if [ -z "${VIRTUAL_ENV:-}" ]; then
        print_error "No active virtual environment detected."
        print_info "Activate the environment first: source ./launch_env.sh $expected"
        return 1
    fi

    local active=""
    if active=$(detect_environment); then
        if [ "$active" != "$expected" ]; then
            print_error "Active virtual environment is '$active', but requested '$expected'."
            print_info "Activate the requested environment first: source ./launch_env.sh $expected"
            return 1
        fi
        return 0
    fi

    print_error "Active virtual environment '$VIRTUAL_ENV' is not managed by this script."
    print_info "Activate the requested environment first: source ./launch_env.sh $expected"
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

run_pip_install() {
    if [ -z "${VIRTUAL_ENV:-}" ]; then
        print_error "No active virtual environment detected for pip install."
        return 1
    fi

    local python_path
    python_path=$(command -v python 2>/dev/null || true)
    if [[ "$python_path" != "$VIRTUAL_ENV/bin/python" ]]; then
        print_error "Active python is not from VIRTUAL_ENV: ${python_path:-not found}"
        print_info "Activate the expected environment first with ./launch_env.sh."
        return 1
    fi

    local cmd=(python -m pip install)
    cmd+=("$@")

    if run_command "${cmd[@]}"; then
        print_info "Packages installed successfully."
        return 0
    fi

    print_error "Package installation failed."
    return 1
}

cuda_version_from_home() {
    local cuda_home="$1"
    [ -n "$cuda_home" ] || return 1
    cuda_home="${cuda_home%/}"
    [ -x "$cuda_home/bin/nvcc" ] || return 1

    "$cuda_home/bin/nvcc" --version 2>/dev/null | sed -n 's/.*release \([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -1
}

detect_active_cuda_version() {
    if [ -n "${ML_ENV_CUDA_VERSION:-}" ]; then
        echo "$ML_ENV_CUDA_VERSION"
        return 0
    fi

    local cuda_version=""
    if cuda_version=$(cuda_version_from_home "${CUDA_HOME:-}"); then
        echo "$cuda_version"
        return 0
    fi

    if cuda_version=$(cuda_version_from_home "${CUDA_PATH:-}"); then
        echo "$cuda_version"
        return 0
    fi

    if command -v nvcc >/dev/null 2>&1; then
        nvcc --version 2>/dev/null | sed -n 's/.*release \([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -1
        return 0
    fi

    python - <<'PY' 2>/dev/null
import sys
try:
    import torch
except Exception:
    sys.exit(1)
if torch.version.cuda:
    print(torch.version.cuda)
    sys.exit(0)
sys.exit(1)
PY
}

install_sglang_cuda_129_wheels() {
    print_info "CUDA 12.9 detected; installing CUDA 12.9 PyTorch and SGLang kernel wheels..."

    run_uv_install --force-reinstall \
        torch==2.11.0 \
        torchaudio==2.11.0 \
        torchvision \
        --index-url https://download.pytorch.org/whl/cu129 || return 1

    run_uv_install --force-reinstall \
        sglang-kernel \
        --index-url https://docs.sglang.ai/whl/cu129/ || return 1

    run_uv_install --force-reinstall \
        sgl-deep-gemm \
        --index-url https://docs.sglang.ai/whl/cu129/ \
        --no-deps || return 1
}

install_bleeding_edge_sglang() {
    local expected_env="$1"
    ensure_active_environment_matches "$expected_env" || return 1

    local target_dir=""
    if [ -n "${SGLANG_DIR:-}" ]; then
        target_dir="$SGLANG_DIR"
    else
        target_dir="$VIRTUAL_ENV/sglang"
    fi

    if [ -e "$target_dir" ] && [ ! -d "$target_dir/.git" ]; then
        print_error "SGLang target exists but is not a git checkout: $target_dir"
        return 1
    fi

    if [ ! -d "$target_dir/.git" ]; then
        local parent_dir
        parent_dir=$(dirname "$target_dir")
        if [ ! -d "$parent_dir" ]; then
            run_command mkdir -p "$parent_dir" || return 1
        fi
        run_command git clone https://github.com/sgl-project/sglang.git "$target_dir" || return 1
    fi

    run_command git -C "$target_dir" fetch origin main --tags || return 1
    run_command git -C "$target_dir" checkout main || return 1
    run_command git -C "$target_dir" pull --ff-only origin main || return 1

    run_uv_install -U --reinstall --prerelease=allow -e "$target_dir/python[all]" || return 1

    local cuda_version=""
    cuda_version=$(detect_active_cuda_version || true)
    if [ "$cuda_version" = "12.9" ]; then
        install_sglang_cuda_129_wheels || return 1
    elif [ -n "$cuda_version" ]; then
        print_info "CUDA $cuda_version detected; no extra CUDA 12.9 wheel reinstall needed."
    else
        print_warning "Could not detect active CUDA version; skipping CUDA 12.9-specific wheel reinstall."
    fi
}

check_kt_kernel_build_dependencies() {
    local missing=()

    if ! command -v cmake >/dev/null 2>&1; then
        missing+=("cmake")
    fi
    if ! command -v pkg-config >/dev/null 2>&1; then
        missing+=("pkg-config")
    elif ! pkg-config --exists hwloc >/dev/null 2>&1; then
        missing+=("libhwloc-dev")
    fi

    if [ "${#missing[@]}" -eq 0 ]; then
        return 0
    fi

    print_error "Missing kt-kernel build dependencies: ${missing[*]}"
    print_info "Install them with your OS package manager, then rerun this script."
    print_info "On Debian/Ubuntu: sudo apt install -y cmake libhwloc-dev pkg-config"
    return 1
}

install_kt_kernel() {
    local ktransformers_dir="$1"
    local kt_kernel_dir="$ktransformers_dir/kt-kernel"

    if [ ! -d "$kt_kernel_dir" ]; then
        print_warning "kt-kernel directory not found at $kt_kernel_dir"
        return 1
    fi

    check_kt_kernel_build_dependencies || return 1
    run_command bash -c "cd \"$kt_kernel_dir\" && ./install.sh build"
}

install_gemma_sglang() {
    print_info "Installing packages for Gemma-4 (SGLang)..."

    install_bleeding_edge_sglang gemma-sglang || return 1
    run_uv_install "git+https://github.com/huggingface/transformers.git@91b1ab1fdfa81a552644a92fbe3e8d88de40e167"
}

install_gemma_vllm() {
    print_info "Installing vLLM for Gemma-4..."
    run_uv_install vllm --torch-backend=auto --extra-index-url https://wheels.vllm.ai/nightly
}

install_glm_sglang() {
    print_info "Installing packages for GLM-4/5 (SGLang)..."
    
    install_bleeding_edge_sglang glm-sglang || return 1
    run_uv_install "kernels==0.14.1"
}

install_glm_transformers() {
    print_info "Installing packages for GLM-4/5 (Transformers)..."

    run_uv_install git+https://github.com/huggingface/transformers.git@76732b4e7120808ff989edbd16401f61fa6a0afa
}

install_glm_vllm() {
    print_info "Installing packages for GLM-4/5 (vLLM)..."
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

install_deepseek_ktransformers() {
    print_info "Installing KTransformers for DeepSeek-V3/V4/R1/OCR..."
    ensure_active_environment_matches deepseek-ktransformers || return 1

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

    install_kt_kernel "$ktransformers_dir" || return 1

    print_info "Installing SGLang for DeepSeek-V3/V4/R1/OCR from ktransformers checkout..."

    if [ ! -x "$ktransformers_dir/install.sh" ]; then
        print_error "ktransformers installer not found or not executable at $ktransformers_dir/install.sh"
        return 1
    fi

    run_command bash -c "cd \"$ktransformers_dir\" && ./install.sh sglang --editable" || return 1
    run_pip_install "tilelang==0.1.8" || return 1
    run_pip_install "apache-tvm-ffi==0.1.9" || return 1
    run_pip_install --upgrade flashinfer-python flashinfer-cubin || return 1
    run_pip_install "transformers==4.57.1" || return 1

    print_info "Installing FlashMLA for DeepSeek V4 compressed attention..."
    local flash_mla_env=(
        env
        "NVCC_THREADS=${NVCC_THREADS:-8}"
    )

    local cuda_home="${CUDA_HOME:-${CUDA_PATH:-}}"
    if [ -z "$cuda_home" ] && command -v nvcc >/dev/null 2>&1; then
        cuda_home=$(cd -- "$(dirname -- "$(command -v nvcc)")/.." && pwd)
    fi

    if [ -z "$cuda_home" ] || [ ! -x "$cuda_home/bin/nvcc" ]; then
        print_error "No active CUDA toolkit with nvcc detected for FlashMLA."
        print_info "Activate an environment configured by 05_setup_env.sh/launch_env.sh with a CUDA toolkit selected."
        return 1
    fi

    flash_mla_env+=(
        "CUDA_HOME=$cuda_home"
        "CUDA_PATH=$cuda_home"
        "PATH=$cuda_home/bin:$PATH"
        "LD_LIBRARY_PATH=$cuda_home/lib:$cuda_home/lib64:${LD_LIBRARY_PATH:-}"
        "LIBRARY_PATH=$cuda_home/lib:$cuda_home/lib64:${LIBRARY_PATH:-}"
    )

    if [ -d "$cuda_home/include/cccl" ]; then
        flash_mla_env+=("CPATH=$cuda_home/include/cccl:${CPATH:-}")
    fi

    local gpu_name=""
    if command -v nvidia-smi >/dev/null 2>&1; then
        gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 | tr '[:lower:]' '[:upper:]')
    fi
    if [[ "$gpu_name" != *"B200"* && "$gpu_name" != *"BLACKWELL"* ]]; then
        flash_mla_env+=("FLASH_MLA_DISABLE_SM100=1")
    fi

    run_command "${flash_mla_env[@]}" python -m pip install --no-build-isolation \
        'flash-mla @ git+https://github.com/deepseek-ai/FlashMLA.git@9241ae3ef9bac614dd25e45e507e089f888280e0' || return 1

    run_command python -c "import flash_mla; from flash_mla.flash_mla_interface import FlashMLASchedMeta; print('flash_mla import OK')" || return 1

    run_pip_install nvidia-cudnn-cu12==9.16.0.29 || return 1
}

install_deepseek_sglang() {
    print_info "Installing SGLang for DeepSeek..."

    install_bleeding_edge_sglang deepseek-sglang || return 1

    local cuda_home="${CUDA_HOME:-${CUDA_PATH:-}}"
    if [ -z "$cuda_home" ] && command -v nvcc >/dev/null 2>&1; then
        cuda_home=$(cd -- "$(dirname -- "$(command -v nvcc)")/.." && pwd)
    fi

    if [ -z "$cuda_home" ] || [ ! -x "$cuda_home/bin/nvcc" ]; then
        print_error "No active CUDA toolkit with nvcc detected for FlashMLA."
        print_info "Activate an environment configured by 05_setup_env.sh/launch_env.sh with a CUDA toolkit selected."
        return 1
    fi

    export CUDA_HOME="$cuda_home"
    export CUDA_PATH="$cuda_home"
    export PATH="$cuda_home/bin:$PATH"
    export LD_LIBRARY_PATH="$cuda_home/lib:$cuda_home/lib64:${LD_LIBRARY_PATH:-}"
    export LIBRARY_PATH="$cuda_home/lib:$cuda_home/lib64:${LIBRARY_PATH:-}"

    print_info "Installing FlashMLA with CUDA_HOME=$cuda_home..."
    local cpath_value="${CPATH:-}"
    if [ -d "$cuda_home/include/cccl" ]; then
        cpath_value="$cuda_home/include/cccl:$cpath_value"
    fi

    local flash_mla_env=(
        env
        "CUDA_HOME=$CUDA_HOME"
        "CUDA_PATH=$CUDA_PATH"
        "PATH=$PATH"
        "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
        "LIBRARY_PATH=$LIBRARY_PATH"
        "CPATH=$cpath_value"
        "NVCC_THREADS=${NVCC_THREADS:-8}"
    )

    local gpu_name=""
    if command -v nvidia-smi >/dev/null 2>&1; then
        gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 | tr '[:lower:]' '[:upper:]')
    fi
    if [[ "$gpu_name" != *"B200"* && "$gpu_name" != *"BLACKWELL"* ]]; then
        flash_mla_env+=("FLASH_MLA_DISABLE_SM100=1")
    fi

    run_command "${flash_mla_env[@]}" uv pip install --no-build-isolation \
        'flash-mla @ git+https://github.com/deepseek-ai/FlashMLA.git@9241ae3ef9bac614dd25e45e507e089f888280e0' || return 1

    run_command python -c "import flash_mla; from flash_mla.flash_mla_interface import FlashMLASchedMeta; print('flash_mla import OK')" || return 1
}

install_deepseek_vllm() {
    print_info "Installing vLLM for DeepSeek..."
    run_uv_install -U vllm --torch-backend auto || return 1

    if [ -z "${VIRTUAL_ENV:-}" ]; then
        print_error "No active virtual environment detected for DeepGEMM install."
        return 1
    fi

    local deepgemm_installer="$VIRTUAL_ENV/install_deepgemm.sh"
    local deepgemm_installer_url="https://raw.githubusercontent.com/vllm-project/vllm/main/tools/install_deepgemm.sh"

    print_info "Downloading vLLM DeepGEMM installer into $VIRTUAL_ENV..."
    run_command curl -fsSL "$deepgemm_installer_url" -o "$deepgemm_installer" || return 1
    run_command chmod +x "$deepgemm_installer" || return 1

    print_info "Installing DeepGEMM for DeepSeek vLLM..."
    # shellcheck disable=SC2016
    run_command env VIRTUAL_ENV="$VIRTUAL_ENV" PATH="$VIRTUAL_ENV/bin:$PATH" \
        bash -c 'cd "$1" && bash "$2"' _ "$VIRTUAL_ENV" "$deepgemm_installer" || return 1
}

install_gptoss_transformers() {
    print_info "Installing Transformers stack for gpt-oss..."
    run_uv_install -U transformers accelerate torch triton==3.4 kernels
}

install_gptoss_vllm() {
    print_info "Installing vLLM for gpt-oss..."
    run_uv_install vllm --torch-backend=auto --extra-index-url https://wheels.vllm.ai/nightly
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

    install_kt_kernel "$ktransformers_dir" || return 1

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

    run_pip_install -e "$sglang_dir/python[all]" || return 1
    run_pip_install nvidia-cudnn-cu12==9.16.0.29 || return 1
}
install_kimi_sglang() {
    print_info "Installing SGLang for Kimi K2.X..."
    install_bleeding_edge_sglang kimi-sglang || return 1
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

install_ling_sglang() {
    print_info "Installing SGLang for Ling-2.6..."

    install_bleeding_edge_sglang ling-sglang || return 1
}

install_ling_transformers() {
    print_info "No package install configured for Ling-2.6 (Transformers) yet."
}

install_ling_vllm() {
    print_info "Installing vLLM for Ling-2.6..."

    local target_dir=""
    if [ -n "${VLLM_DIR:-}" ]; then
        target_dir="$VLLM_DIR"
    elif [ -n "${VIRTUAL_ENV:-}" ]; then
        target_dir="$VIRTUAL_ENV/vllm"
    else
        print_error "No active virtual environment detected for Ling-2.6 vLLM clone."
        return 1
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
        run_command git clone https://github.com/vllm-project/vllm.git "$target_dir" || return 1
    fi

    # shellcheck disable=SC2016
    run_command env VLLM_USE_PRECOMPILED=1 bash -c 'cd "$1" && uv pip install --editable . --torch-backend=auto' _ "$target_dir" || return 1
}

install_minimax_sglang() {
    print_info "Installing SGLang for MiniMax-M2.X..."

    install_bleeding_edge_sglang minimax-sglang || return 1
}

install_minimax_transformers() {
    print_info "Installing Transformers for MiniMax-M2.X..."
    run_uv_install "transformers==4.57.1" "torch" "accelerate" "--torch-backend=auto"
}

install_minimax_vllm() {
    print_info "Installing vLLM for MiniMax-M2.X..."
    run_uv_install vllm --torch-backend=auto --extra-index-url https://wheels.vllm.ai/nightly
}

install_nemotron_sglang() {
    print_info "Installing SGLang for Nemotron-3..."
    install_bleeding_edge_sglang nemotron-sglang || return 1
}

install_nemotron_trtllm() {
    print_info "Installing TRT-LLM dependencies for Nemotron-3..."
    run_uv_install torch==2.9.1 openai==2.6.1 requests
}

install_nemotron_vllm() {
    print_info "Installing vLLM for Nemotron-3..."
    run_uv_install vllm --torch-backend=auto --extra-index-url https://wheels.vllm.ai/nightly
}

install_qwen3_ktransformers() {
    print_info "Installing KTransformers stack for Qwen3..."
    ensure_active_environment_matches qwen3-ktransformers || return 1

    run_pip_install --upgrade --force-reinstall \
        'torch==2.9.1' \
        'torchvision==0.24.1' \
        'torchaudio==2.9.1' \
        'sglang-kt==0.5.2.post2' \
        'tilelang' \
        'kt-kernel==0.5.2' || return 1

    run_pip_install --force-reinstall --no-deps 'nvidia-cudnn-cu12==9.16.0.29'
}

install_qwen3_sglang() {
    print_info "Installing SGLang for Qwen3..."
    install_bleeding_edge_sglang qwen3-sglang || return 1
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
        deepseek-ktransformers)
            install_deepseek_ktransformers || return 1
            ACTION_TAKEN=true
            ;;
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
        gemma-sglang)
            install_gemma_sglang || return 1
            ACTION_TAKEN=true
            ;;
        gemma-vllm)
            install_gemma_vllm || return 1
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
        ling-sglang)
            install_ling_sglang || return 1
            ACTION_TAKEN=true
            ;;
        ling-transformers)
            install_ling_transformers || return 1
            ACTION_TAKEN=true
            ;;
        ling-vllm)
            install_ling_vllm || return 1
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
        nemotron-sglang)
            install_nemotron_sglang || return 1
            ACTION_TAKEN=true
            ;;
        nemotron-trtllm)
            install_nemotron_trtllm || return 1
            ACTION_TAKEN=true
            ;;
        nemotron-vllm)
            install_nemotron_vllm || return 1
            ACTION_TAKEN=true
            ;;
        qwen3-ktransformers)
            install_qwen3_ktransformers || return 1
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
        echo "Usage: ./06_install_packages.sh [--env ENV_NAME]"
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
            print_info "Nothing to configure in 06_install_packages.sh."
            return 0
        fi
    else
        if ! env_type=$(detect_environment); then
            if [ -n "${VIRTUAL_ENV:-}" ]; then
                print_warning "Active virtual environment '$VIRTUAL_ENV' is not managed by this script."
            else
                print_info "No active virtual environment detected."
            fi
            print_info "Nothing to configure in 06_install_packages.sh."
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
