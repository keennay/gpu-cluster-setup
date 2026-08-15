#!/bin/bash

# Script: 06_install_packages.sh
# Purpose: Provide environment placeholders without installing packages.
# Usage: ./06_install_packages.sh [ENV_NAME]

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
  "allenai-transformers"
  "allenai-vllm"
  "arcee-transformers"
  "arcee-vllm"
  "arcee-nvfp4-vllm"
  "cohere-transformers"
  "cohere-vllm"
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
  "inclusionai-sglang"
  "inclusionai-transformers"
  "inclusionai-vllm"
  "intel-vllm"
  "kimi-ktransformers"
  "kimi-sglang"
  "kimi-vllm"
  "laguna-sglang"
  "laguna-trtllm"
  "laguna-vllm"
  "liquidai-sglang"
  "liquidai-transformers"
  "liquidai-vllm"
  "microsoft-vllm"
  "minimax-ktransformers"
  "minimax-sglang"
  "minimax-transformers"
  "minimax-vllm"
  "mistralai-transformers"
  "mistralai-vllm"
  "nanbeige-sglang"
  "nanbeige-transformers"
  "nanbeige-vllm"
  "nemotron-sglang"
  "nemotron-trtllm"
  "nemotron-vllm"
  "nvidia-vllm"
  "poolside-sglang"
  "poolside-transformers"
  "poolside-laguna-vllm"
  "poolside-laguna-s21-vllm"
  "primeintellect-vllm"
  "qwen-ktransformers"
  "qwen-sglang"
  "qwen-transformers"
  "qwen-vllm"
  "redhat-vllm"
  "stepfun-sglang"
  "stepfun-transformers"
  "stepfun-vllm"
  "zyphra-transformers"
  "zyphra-vllm"
  "zyphra-legacy-transformers"
  "zyphra-legacy-vllm"
  "custom_uv"
  "custom_pip"
)

declare -A ENV_DESCRIPTIONS=(
  ["allenai-transformers"]="AllenAI (Transformers)"
  ["allenai-vllm"]="AllenAI (vLLM)"
  ["arcee-transformers"]="Arcee (Transformers)"
  ["arcee-vllm"]="Arcee (vLLM)"
  ["arcee-nvfp4-vllm"]="Arcee NVFP4 (vLLM)"
  ["cohere-transformers"]="Cohere (Transformers)"
  ["cohere-vllm"]="Cohere (vLLM)"
  ["deepseek-ktransformers"]="DeepSeek (KTransformers)"
  ["deepseek-lmdeploy"]="DeepSeek (LMDeploy)"
  ["deepseek-sglang"]="DeepSeek (SGLang)"
  ["deepseek-vllm"]="DeepSeek (vLLM)"
  ["gemma-sglang"]="Gemma (SGLang)"
  ["gemma-vllm"]="Gemma (vLLM)"
  ["glm-ktransformers"]="GLM (KTransformers)"
  ["glm-sglang"]="GLM (SGLang)"
  ["glm-transformers"]="GLM (Transformers)"
  ["glm-vllm"]="GLM (vLLM)"
  ["gpt-oss-transformers"]="gpt-oss (Transformers)"
  ["gpt-oss-vllm"]="gpt-oss (vLLM)"
  ["inclusionai-sglang"]="InclusionAI (SGLang)"
  ["inclusionai-transformers"]="InclusionAI (Transformers)"
  ["inclusionai-vllm"]="InclusionAI (vLLM)"
  ["intel-vllm"]="Intel (vLLM)"
  ["kimi-ktransformers"]="Kimi (KTransformers)"
  ["kimi-sglang"]="Kimi (SGLang)"
  ["kimi-vllm"]="Kimi (vLLM)"
  ["laguna-sglang"]="Laguna (SGLang)"
  ["laguna-trtllm"]="Laguna (TRT-LLM)"
  ["laguna-vllm"]="Laguna (vLLM)"
  ["liquidai-sglang"]="LiquidAI (SGLang)"
  ["liquidai-transformers"]="LiquidAI (Transformers)"
  ["liquidai-vllm"]="LiquidAI (vLLM)"
  ["microsoft-vllm"]="Microsoft (vLLM)"
  ["minimax-ktransformers"]="MiniMax (KTransformers)"
  ["minimax-sglang"]="MiniMax (SGLang)"
  ["minimax-transformers"]="MiniMax (Transformers)"
  ["minimax-vllm"]="MiniMax (vLLM)"
  ["mistralai-transformers"]="MistralAI (Transformers)"
  ["mistralai-vllm"]="MistralAI (vLLM)"
  ["nanbeige-sglang"]="Nanbeige (SGLang)"
  ["nanbeige-transformers"]="Nanbeige (Transformers)"
  ["nanbeige-vllm"]="Nanbeige (vLLM)"
  ["nemotron-sglang"]="Nemotron (SGLang)"
  ["nemotron-trtllm"]="Nemotron (TRT-LLM)"
  ["nemotron-vllm"]="Nemotron (vLLM)"
  ["nvidia-vllm"]="NVIDIA (vLLM)"
  ["poolside-sglang"]="Poolside (SGLang)"
  ["poolside-transformers"]="Poolside (Transformers)"
  ["poolside-laguna-vllm"]="Poolside Laguna (vLLM)"
  ["poolside-laguna-s21-vllm"]="Poolside Laguna S 2.1 (vLLM)"
  ["primeintellect-vllm"]="PrimeIntellect (vLLM)"
  ["qwen-ktransformers"]="Qwen (KTransformers)"
  ["qwen-sglang"]="Qwen (SGLang)"
  ["qwen-transformers"]="Qwen (Transformers)"
  ["qwen-vllm"]="Qwen (vLLM)"
  ["redhat-vllm"]="RedHat (vLLM)"
  ["stepfun-sglang"]="StepFun (SGLang)"
  ["stepfun-transformers"]="StepFun (Transformers)"
  ["stepfun-vllm"]="StepFun (vLLM)"
  ["zyphra-transformers"]="Zyphra (Transformers)"
  ["zyphra-vllm"]="Zyphra (vLLM)"
  ["zyphra-legacy-transformers"]="Zyphra Legacy (Transformers)"
  ["zyphra-legacy-vllm"]="Zyphra Legacy (vLLM)"
  ["custom_uv"]="Custom (uv)"
  ["custom_pip"]="Custom (pip)"
)

resolve_env_type() {
    local input="${1#env_}"

    case "$input" in
        1|allenai_transformers|allenai-transformers)
            echo "allenai-transformers"
            ;;
        2|allenai_vllm|allenai-vllm)
            echo "allenai-vllm"
            ;;
        3|arcee_transformers|arcee-transformers)
            echo "arcee-transformers"
            ;;
        4|arcee_vllm|arcee-vllm)
            echo "arcee-vllm"
            ;;
        5|arcee_nvfp4_vllm|arcee-nvfp4-vllm)
            echo "arcee-nvfp4-vllm"
            ;;
        6|cohere_transformers|cohere-transformers)
            echo "cohere-transformers"
            ;;
        7|cohere_vllm|cohere-vllm)
            echo "cohere-vllm"
            ;;
        8|deepseek_ktransformers|deepseek-ktransformers)
            echo "deepseek-ktransformers"
            ;;
        9|deepseek_lmdeploy|deepseek-lmdeploy)
            echo "deepseek-lmdeploy"
            ;;
        10|deepseek_sglang|deepseek-sglang)
            echo "deepseek-sglang"
            ;;
        11|deepseek_vllm|deepseek-vllm)
            echo "deepseek-vllm"
            ;;
        12|gemma_sglang|gemma-sglang|gemma4_sglang|gemma4-sglang|gemma_4_sglang|gemma-4-sglang)
            echo "gemma-sglang"
            ;;
        13|gemma_vllm|gemma-vllm|gemma4_vllm|gemma4-vllm|gemma_4_vllm|gemma-4-vllm)
            echo "gemma-vllm"
            ;;
        14|glm_ktransformers|glm-ktransformers)
            echo "glm-ktransformers"
            ;;
        15|glm_sglang|glm-sglang)
            echo "glm-sglang"
            ;;
        16|glm_transformers|glm-transformers)
            echo "glm-transformers"
            ;;
        17|glm_vllm|glm-vllm)
            echo "glm-vllm"
            ;;
        18|gptoss_transformers|gpt-oss_transformers|gptoss-transformers|gpt-oss-transformers)
            echo "gpt-oss-transformers"
            ;;
        19|gptoss_vllm|gpt-oss_vllm|vllm_gptoss|gptoss-vllm|gpt-oss-vllm)
            echo "gpt-oss-vllm"
            ;;
        20|inclusionai_sglang|inclusionai-sglang)
            echo "inclusionai-sglang"
            ;;
        21|inclusionai_transformers|inclusionai-transformers)
            echo "inclusionai-transformers"
            ;;
        22|inclusionai_vllm|inclusionai-vllm)
            echo "inclusionai-vllm"
            ;;
        23|intel_vllm|intel-vllm)
            echo "intel-vllm"
            ;;
        24|kimi_ktransformers|kimi-ktransformers)
            echo "kimi-ktransformers"
            ;;
        25|kimi_sglang|kimi-sglang)
            echo "kimi-sglang"
            ;;
        26|kimi_vllm|kimi-vllm)
            echo "kimi-vllm"
            ;;
        27|laguna_sglang|laguna-sglang)
            echo "laguna-sglang"
            ;;
        28|laguna_trtllm|laguna-trtllm|laguna_trt_llm|laguna-trt-llm)
            echo "laguna-trtllm"
            ;;
        29|laguna_vllm|laguna-vllm)
            echo "laguna-vllm"
            ;;
        30|liquidai_sglang|liquidai-sglang)
            echo "liquidai-sglang"
            ;;
        31|liquidai_transformers|liquidai-transformers)
            echo "liquidai-transformers"
            ;;
        32|liquidai_vllm|liquidai-vllm)
            echo "liquidai-vllm"
            ;;
        33|microsoft_vllm|microsoft-vllm)
            echo "microsoft-vllm"
            ;;
        34|minimax_ktransformers|minimax-ktransformers)
            echo "minimax-ktransformers"
            ;;
        35|minimax_sglang|minimax-sglang)
            echo "minimax-sglang"
            ;;
        36|minimax_transformers|minimax-transformers)
            echo "minimax-transformers"
            ;;
        37|minimax_vllm|minimax-vllm)
            echo "minimax-vllm"
            ;;
        38|mistralai_transformers|mistralai-transformers)
            echo "mistralai-transformers"
            ;;
        39|mistralai_vllm|mistralai-vllm)
            echo "mistralai-vllm"
            ;;
        40|nanbeige_sglang|nanbeige-sglang)
            echo "nanbeige-sglang"
            ;;
        41|nanbeige_transformers|nanbeige-transformers)
            echo "nanbeige-transformers"
            ;;
        42|nanbeige_vllm|nanbeige-vllm)
            echo "nanbeige-vllm"
            ;;
        43|nemotron_sglang|nemotron-sglang)
            echo "nemotron-sglang"
            ;;
        44|nemotron_trtllm|nemotron-trtllm|nemotron_trt_llm|nemotron-trt-llm)
            echo "nemotron-trtllm"
            ;;
        45|nemotron_vllm|nemotron-vllm)
            echo "nemotron-vllm"
            ;;
        46|nvidia_vllm|nvidia-vllm)
            echo "nvidia-vllm"
            ;;
        47|poolside_sglang|poolside-sglang)
            echo "poolside-sglang"
            ;;
        48|poolside_transformers|poolside-transformers)
            echo "poolside-transformers"
            ;;
        49|poolside_laguna_vllm|poolside-laguna-vllm)
            echo "poolside-laguna-vllm"
            ;;
        50|poolside_laguna_s21_vllm|poolside-laguna-s21-vllm)
            echo "poolside-laguna-s21-vllm"
            ;;
        51|primeintellect_vllm|primeintellect-vllm)
            echo "primeintellect-vllm"
            ;;
        52|qwen_ktransformers|qwen-ktransformers)
            echo "qwen-ktransformers"
            ;;
        53|qwen_sglang|qwen-sglang)
            echo "qwen-sglang"
            ;;
        54|qwen_transformers|qwen-transformers)
            echo "qwen-transformers"
            ;;
        55|qwen_vllm|qwen-vllm)
            echo "qwen-vllm"
            ;;
        56|redhat_vllm|redhat-vllm)
            echo "redhat-vllm"
            ;;
        57|stepfun_sglang|stepfun-sglang)
            echo "stepfun-sglang"
            ;;
        58|stepfun_transformers|stepfun-transformers)
            echo "stepfun-transformers"
            ;;
        59|stepfun_vllm|stepfun-vllm)
            echo "stepfun-vllm"
            ;;
        60|zyphra_transformers|zyphra-transformers)
            echo "zyphra-transformers"
            ;;
        61|zyphra_vllm|zyphra-vllm)
            echo "zyphra-vllm"
            ;;
        62|zyphra_legacy_transformers|zyphra-legacy-transformers)
            echo "zyphra-legacy-transformers"
            ;;
        63|zyphra_legacy_vllm|zyphra-legacy-vllm)
            echo "zyphra-legacy-vllm"
            ;;
        64|custom|custom_uv|custom-uv|env_custom_uv)
            echo "custom_uv"
            ;;
        65|custom_pip|custom-pip|env_custom_pip)
            echo "custom_pip"
            ;;
        *)
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

activate_environment_override() {
    local env_type="$1"
    local env_path="$HOME/env_${env_type}"
    local activate_script=""

    if [ ! -d "$env_path" ]; then
        print_error "Requested environment not found: $env_path"
        print_info "Create it first: ./05_setup_env.sh env_${env_type} --auto"
        return 1
    fi

    if [ ! -x "$env_path/bin/python" ]; then
        print_error "Requested environment has no working Python interpreter: $env_path/bin/python"
        print_info "Rebuild it with: ./05_setup_env.sh env_${env_type} --auto"
        return 1
    fi

    if [ -f "$env_path/activate_ml" ]; then
        activate_script="$env_path/activate_ml"
    elif [ -f "$env_path/bin/activate" ]; then
        activate_script="$env_path/bin/activate"
    else
        print_error "Requested environment has no activation script: $env_path"
        print_info "Rebuild it with: ./05_setup_env.sh env_${env_type} --auto"
        return 1
    fi

    print_info "Activating requested environment: $env_path"
    # shellcheck source=/dev/null
    if ! source "$activate_script"; then
        print_error "Failed to activate requested environment: $env_path"
        return 1
    fi

    if [ "${VIRTUAL_ENV:-}" != "$env_path" ]; then
        print_error "Activation did not select the requested environment: $env_path"
        return 1
    fi
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

install_flashinfer_python311_compatible() {
    local incompatible_package

    if ! python -c 'import sys; raise SystemExit(0 if sys.version_info < (3, 12) else 1)'; then
        return 0
    fi

    print_info "Installing FlashInfer 0.6.17 for Python 3.10/3.11 annotation compatibility..."
    run_uv_install --upgrade --no-deps "flashinfer-python==0.6.17" || return 1

    for incompatible_package in flashinfer-cubin flashinfer-jit-cache; do
        if python -c 'import importlib.metadata as m, sys; m.version(sys.argv[1])' \
            "$incompatible_package" >/dev/null 2>&1; then
            print_info "Removing incompatible $incompatible_package companion package..."
            run_command uv pip uninstall "$incompatible_package" || return 1
        fi
    done
}

install_vllm_pinned_commit_python311_compatible() {
    local source_commit="52be12cfac0c5a18ba906814b2d2bcadb40a9c4b"
    local source_dir=""

    if [ -z "${VIRTUAL_ENV:-}" ]; then
        print_error "No active virtual environment detected for the vLLM source checkout."
        return 1
    fi
    source_dir="$VIRTUAL_ENV/vllm"

    if [ -e "$source_dir" ] && [ ! -d "$source_dir/.git" ]; then
        print_error "vLLM target exists but is not a git checkout: $source_dir"
        return 1
    fi

    if [ ! -d "$source_dir/.git" ]; then
        run_command git clone https://github.com/vllm-project/vllm.git \
            "$source_dir" || return 1
    fi

    run_command git -C "$source_dir" fetch origin --tags || return 1
    run_command git -C "$source_dir" checkout --force "$source_commit" || return 1

    print_info "Installing pinned GitHub commit $source_commit from $source_dir..."
    VLLM_USE_PRECOMPILED=1 \
        VLLM_PRECOMPILED_WHEEL_COMMIT="$source_commit" \
        run_uv_install -U --reinstall --prerelease=allow \
        -e "$source_dir" --torch-backend=auto || return 1

    install_flashinfer_python311_compatible || return 1
}

install_allenai_vllm() {
    print_info "Installing the pinned GitHub vLLM commit for AllenAI..."
    install_vllm_pinned_commit_python311_compatible || return 1
}

install_arcee_deepgemm() {
    if [ -z "${VIRTUAL_ENV:-}" ]; then
        print_error "No active virtual environment detected for DeepGEMM install."
        return 1
    fi

    local vllm_ref="${1:-v0.18.0}"
    local deepgemm_installer="$VIRTUAL_ENV/install_deepgemm.sh"
    local deepgemm_installer_url="https://raw.githubusercontent.com/vllm-project/vllm/$vllm_ref/tools/install_deepgemm.sh"

    print_info "Downloading vLLM $vllm_ref DeepGEMM installer into $VIRTUAL_ENV..."
    run_command curl -fsSL "$deepgemm_installer_url" -o "$deepgemm_installer" || return 1
    run_command chmod +x "$deepgemm_installer" || return 1

    print_info "Installing vLLM $vllm_ref's pinned DeepGEMM build for Arcee..."
    # shellcheck disable=SC2016
    run_command env VIRTUAL_ENV="$VIRTUAL_ENV" PATH="$VIRTUAL_ENV/bin:$PATH" \
        bash -c 'cd "$1" && bash "$2"' _ "$VIRTUAL_ENV" "$deepgemm_installer" || return 1
}

install_arcee_vllm() {
    print_info "Installing the pinned GitHub vLLM commit for Arcee..."
    install_vllm_pinned_commit_python311_compatible || return 1
    install_arcee_deepgemm "52be12cfac0c5a18ba906814b2d2bcadb40a9c4b" || return 1
}

install_arcee_nvfp4_vllm() {
    print_info "Installing vLLM 0.18.0 for Arcee NVFP4..."
    run_uv_install -U "vllm==0.18.0" || return 1
    install_arcee_deepgemm "v0.18.0" || return 1
}

install_cohere_vllm() {
    print_info "Installing the pinned GitHub vLLM commit and Cohere Melody for Cohere..."
    install_vllm_pinned_commit_python311_compatible || return 1
    run_uv_install "transformers>=5,<6" || return 1
    run_uv_install "cohere_melody>=0.9.0" || return 1
}

install_gemma_sglang() {
    print_info "Installing packages for Gemma (SGLang)..."

    install_bleeding_edge_sglang gemma-sglang || return 1
    run_uv_install "git+https://github.com/huggingface/transformers.git@91b1ab1fdfa81a552644a92fbe3e8d88de40e167"
}

install_gemma_vllm() {
    print_info "Installing the pinned GitHub vLLM commit for Gemma..."
    install_vllm_pinned_commit_python311_compatible || return 1
}

install_glm_sglang() {
    print_info "Installing packages for GLM (SGLang)..."
    
    install_bleeding_edge_sglang glm-sglang || return 1
    run_uv_install "kernels==0.14.1"
}

install_glm_transformers() {
    print_info "Installing packages for GLM (Transformers)..."

    run_uv_install git+https://github.com/huggingface/transformers.git@76732b4e7120808ff989edbd16401f61fa6a0afa
}

install_glm_vllm() {
    print_info "Installing packages for GLM (vLLM)..."
    local packages=(
        "git+https://github.com/huggingface/transformers.git"
        "pre-commit>=4.2.0"
        "accelerate>=1.10.1"
    )

    run_uv_install -U vllm --index-url https://pypi.org/simple || return 1
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
    print_info "Installing KTransformers for DeepSeek..."
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

    print_info "Installing SGLang for DeepSeek from ktransformers checkout..."

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
        'flash-mla @ git+https://github.com/deepseek-ai/FlashMLA.git@main' || return 1

    run_command python -c "import flash_mla; from flash_mla.flash_mla_interface import FlashMLASchedMeta; print('flash_mla import OK')" || return 1
}

install_deepseek_vllm() {
    print_info "Installing vLLM 0.25.0 for DeepSeek..."
    run_uv_install "vllm==0.25.0" || return 1
}

install_gptoss_transformers() {
    print_info "Installing Transformers stack for gpt-oss..."
    run_uv_install -U transformers accelerate torch triton==3.4 kernels
}

install_gptoss_vllm() {
    print_info "Installing the pinned GitHub vLLM commit for GPT-OSS..."
    install_vllm_pinned_commit_python311_compatible || return 1
}

install_intel_vllm() {
    print_info "Installing the pinned GitHub vLLM commit for Intel..."
    install_vllm_pinned_commit_python311_compatible || return 1
}

install_kimi_ktransformers() {
    print_info "Installing KTransformers for Kimi..."

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

    print_info "Installing SGLang for Kimi..."

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
    print_info "Installing SGLang for Kimi..."
    install_bleeding_edge_sglang kimi-sglang || return 1
    run_uv_install remote_pdb
    run_uv_install imageio
    run_uv_install diffusers
    run_uv_install addict
    run_uv_install cache_dit
    run_uv_install nvidia-cudnn-cu12==9.16.0.29
}

install_kimi_vllm() {
    print_info "Installing vLLM for Kimi..."
    run_uv_install -U vllm --index-url https://pypi.org/simple || return 1
}

install_laguna_sglang() {
    print_info "No package install configured for Laguna (SGLang) yet."
}

install_laguna_trtllm() {
    print_info "No package install configured for Laguna (TRT-LLM) yet."
}

install_laguna_vllm() {
    print_info "Installing vLLM for Laguna..."
    run_uv_install -U vllm --index-url https://pypi.org/simple || return 1
}

install_liquidai_vllm() {
    print_info "Installing the pinned GitHub vLLM commit for LiquidAI..."
    install_vllm_pinned_commit_python311_compatible || return 1
}

install_inclusionai_sglang() {
    print_info "Installing SGLang for InclusionAI..."

    install_bleeding_edge_sglang inclusionai-sglang || return 1
}

install_inclusionai_transformers() {
    print_info "No package install configured for InclusionAI (Transformers) yet."
}

install_inclusionai_vllm() {
    local vllm_version="0.27.2rc1.dev113+g5cecfc013"
    local vllm_wheel="https://wheels.vllm.ai/5cecfc01375052698823fc401e31518fb32a981e/vllm-0.27.2rc1.dev113%2Bg5cecfc013-cp38-abi3-manylinux_2_28_x86_64.whl#sha256=7858cbbd1fbf426a6eac5a9e2dc3779e04ee63705f65c90ab5baca4705a4a638"

    print_info "Installing vLLM $vllm_version for InclusionAI from its immutable commit wheel..."
    run_uv_install --upgrade --reinstall --prerelease=allow \
        "$vllm_wheel" --torch-backend=auto || return 1
}


install_microsoft_vllm() {
    print_info "Installing the pinned GitHub vLLM commit for Microsoft..."
    install_vllm_pinned_commit_python311_compatible || return 1
}

install_minimax_sglang() {
    print_info "Installing SGLang for MiniMax..."

    install_bleeding_edge_sglang minimax-sglang || return 1
}

install_minimax_transformers() {
    print_info "Installing Transformers for MiniMax..."
    run_uv_install "transformers==4.57.1" "torch" "accelerate" "--torch-backend=auto"
}

install_minimax_vllm() {
    print_info "Installing vLLM for MiniMax..."
    run_uv_install -U vllm --index-url https://pypi.org/simple || return 1
}

install_mistralai_vllm() {
    print_info "Installing the pinned GitHub vLLM commit for MistralAI..."
    install_vllm_pinned_commit_python311_compatible || return 1
}

install_nanbeige_vllm() {
    local source_commit="1cf78162bed34ab18ba951396ab5d2c163c85714"

    print_info "Installing the proven Nanbeige vLLM commit $source_commit..."
    ensure_active_environment_matches nanbeige-vllm || return 1

    local target_dir="$VIRTUAL_ENV/vllm"

    if [ -e "$target_dir" ] && [ ! -d "$target_dir/.git" ]; then
        print_error "vLLM target exists but is not a git checkout: $target_dir"
        return 1
    fi

    if [ ! -d "$target_dir/.git" ]; then
        run_command git clone -b nanbeige42 \
            https://github.com/Nanbeige/vllm.git "$target_dir" || return 1
    fi

    run_command git -C "$target_dir" fetch origin nanbeige42 --tags || return 1
    run_command git -C "$target_dir" checkout --force "$source_commit" || return 1

    run_pip_install -e "$target_dir" || return 1
}

install_nemotron_sglang() {
    print_info "Installing SGLang for Nemotron..."
    install_bleeding_edge_sglang nemotron-sglang || return 1
}

install_nemotron_trtllm() {
    print_info "Installing TRT-LLM dependencies for Nemotron..."
    run_uv_install torch==2.9.1 openai==2.6.1 requests
}

install_nemotron_vllm() {
    print_info "Installing the pinned GitHub vLLM commit for the shared Nemotron environment..."
    install_vllm_pinned_commit_python311_compatible || return 1

    if [ -z "${VIRTUAL_ENV:-}" ]; then
        print_error "No active virtual environment detected for DeepGEMM install."
        return 1
    fi

    local deepgemm_installer="$VIRTUAL_ENV/install_deepgemm.sh"
    local deepgemm_installer_url="https://raw.githubusercontent.com/vllm-project/vllm/v0.20.0/tools/install_deepgemm.sh"

    print_info "Installing the proven vLLM 0.20.0 DeepGEMM companion build for Nemotron..."
    run_command curl -fsSL "$deepgemm_installer_url" -o "$deepgemm_installer" || return 1
    run_command env VIRTUAL_ENV="$VIRTUAL_ENV" PATH="$VIRTUAL_ENV/bin:$PATH" \
        bash "$deepgemm_installer" || return 1
}

install_nvidia_vllm() {
    print_info "Installing the pinned GitHub vLLM commit for NVIDIA..."
    install_vllm_pinned_commit_python311_compatible || return 1
}

install_poolside_laguna_vllm() {
    print_info "Installing vLLM 0.26.0 for Poolside Laguna..."
    run_uv_install "vllm==0.26.0" || return 1
}

install_poolside_laguna_s21_vllm() {
    print_info "Installing the pinned GitHub vLLM commit for Poolside Laguna S 2.1..."
    install_vllm_pinned_commit_python311_compatible || return 1
}

install_primeintellect_vllm() {
    print_info "Installing the pinned GitHub vLLM commit for PrimeIntellect..."
    install_vllm_pinned_commit_python311_compatible || return 1
}

install_qwen_ktransformers() {
    print_info "Installing KTransformers stack for Qwen..."
    ensure_active_environment_matches qwen-ktransformers || return 1

    run_pip_install --upgrade --force-reinstall \
        'torch==2.9.1' \
        'torchvision==0.24.1' \
        'torchaudio==2.9.1' \
        'sglang-kt==0.5.2.post2' \
        'tilelang' \
        'kt-kernel==0.5.2' || return 1

    run_pip_install --force-reinstall --no-deps 'nvidia-cudnn-cu12==9.16.0.29'
}

install_qwen_sglang() {
    print_info "Installing SGLang for Qwen..."
    install_bleeding_edge_sglang qwen-sglang || return 1
}

install_qwen_transformers() {
    print_info "Installing Transformers stack for Qwen..."
    run_uv_install "transformers>=4.51.0" "torch>=2.6"
}

install_qwen_vllm() {
    print_info "Installing the pinned GitHub vLLM commit for Qwen..."
    install_vllm_pinned_commit_python311_compatible || return 1
}

install_redhat_vllm() {
    print_info "Installing the pinned GitHub vLLM commit and timm for RedHat..."
    install_vllm_pinned_commit_python311_compatible || return 1
    run_uv_install timm || return 1
}

install_stepfun_vllm() {
    print_info "Installing the pinned GitHub vLLM commit and required Transformers 5 for StepFun..."
    install_vllm_pinned_commit_python311_compatible || return 1
    run_uv_install "transformers>=5,<6" || return 1
}


install_zyphra_vllm() {
    local source_commit="b1b99a08b20f858035894f7f2a8080c556423844"

    print_info "Installing the proven Zyphra vLLM commit $source_commit..."
    ensure_active_environment_matches zyphra-vllm || return 1
    run_pip_install "vllm @ git+https://github.com/Zyphra/vllm.git@$source_commit" || return 1
}

install_zyphra_legacy_vllm() {
    local source_commit="8df704c5258830b18ca19722bcfd40357b410f66"

    print_info "Installing the proven Zyphra Legacy vLLM commit $source_commit..."
    ensure_active_environment_matches zyphra-legacy-vllm || return 1
    run_pip_install "vllm @ git+https://github.com/Zyphra/vllm.git@$source_commit" || return 1
}

perform_environment_action() {
    ACTION_TAKEN=false

    case "$1" in
        allenai-vllm)
            install_allenai_vllm || return 1
            ACTION_TAKEN=true
            ;;
        arcee-vllm)
            install_arcee_vllm || return 1
            ACTION_TAKEN=true
            ;;
        arcee-nvfp4-vllm)
            install_arcee_nvfp4_vllm || return 1
            ACTION_TAKEN=true
            ;;
        cohere-vllm)
            install_cohere_vllm || return 1
            ACTION_TAKEN=true
            ;;
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
        inclusionai-sglang)
            install_inclusionai_sglang || return 1
            ACTION_TAKEN=true
            ;;
        inclusionai-transformers)
            install_inclusionai_transformers || return 1
            ACTION_TAKEN=true
            ;;
        inclusionai-vllm)
            install_inclusionai_vllm || return 1
            ACTION_TAKEN=true
            ;;
        intel-vllm)
            install_intel_vllm || return 1
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
        laguna-sglang)
            install_laguna_sglang || return 1
            ACTION_TAKEN=true
            ;;
        laguna-trtllm)
            install_laguna_trtllm || return 1
            ACTION_TAKEN=true
            ;;
        laguna-vllm)
            install_laguna_vllm || return 1
            ACTION_TAKEN=true
            ;;
        liquidai-vllm)
            install_liquidai_vllm || return 1
            ACTION_TAKEN=true
            ;;
        microsoft-vllm)
            install_microsoft_vllm || return 1
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
        mistralai-vllm)
            install_mistralai_vllm || return 1
            ACTION_TAKEN=true
            ;;
        nanbeige-vllm)
            install_nanbeige_vllm || return 1
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
        nvidia-vllm)
            install_nvidia_vllm || return 1
            ACTION_TAKEN=true
            ;;
        poolside-laguna-vllm)
            install_poolside_laguna_vllm || return 1
            ACTION_TAKEN=true
            ;;
        poolside-laguna-s21-vllm)
            install_poolside_laguna_s21_vllm || return 1
            ACTION_TAKEN=true
            ;;
        primeintellect-vllm)
            install_primeintellect_vllm || return 1
            ACTION_TAKEN=true
            ;;
        qwen-ktransformers)
            install_qwen_ktransformers || return 1
            ACTION_TAKEN=true
            ;;
        qwen-sglang)
            install_qwen_sglang || return 1
            ACTION_TAKEN=true
            ;;
        qwen-transformers)
            install_qwen_transformers || return 1
            ACTION_TAKEN=true
            ;;
        qwen-vllm)
            install_qwen_vllm || return 1
            ACTION_TAKEN=true
            ;;
        redhat-vllm)
            install_redhat_vllm || return 1
            ACTION_TAKEN=true
            ;;
        stepfun-vllm)
            install_stepfun_vllm || return 1
            ACTION_TAKEN=true
            ;;
        zyphra-vllm)
            install_zyphra_vllm || return 1
            ACTION_TAKEN=true
            ;;
        zyphra-legacy-vllm)
            install_zyphra_legacy_vllm || return 1
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
            -h|--help)
                show_help=true
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                return 1
                ;;
            *)
                if [ -n "$override" ]; then
                    print_error "Only one environment may be specified."
                    return 1
                fi
                override="$1"
                shift
                ;;
        esac
    done

    if [ "$show_help" = true ]; then
        echo "Usage: ./06_install_packages.sh [ENV_NAME]"
        echo
        print_env_options
        return 0
    fi

    local env_type=""

    if [ -n "$override" ]; then
        if env_type=$(resolve_env_type "$override"); then
            print_info "Environment override provided: $env_type"
            if ! activate_environment_override "$env_type"; then
                return 1
            fi
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
