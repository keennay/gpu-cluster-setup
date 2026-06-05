#!/bin/bash

# Script: launch_env.sh
# Purpose: Activate ML environment with all optimizations
# Usage: source launch_env.sh [--auto] [env_name]

# Source bashrc to ensure environment is properly loaded
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
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
        7|glm_sglang|glm-sglang|glm45-sglang)
            echo "glm-sglang"
            ;;
        8|glm_transformers|glm-transformers)
            echo "glm-transformers"
            ;;
        9|glm_vllm|glm-vllm)
            echo "glm-vllm"
            ;;
        10|gptoss_transformers|gpt-oss_transformers|gptoss-transformers|gpt-oss-transformers)
            echo "gpt-oss-transformers"
            ;;
        11|gptoss_vllm|gpt-oss_vllm|vllm_gptoss|gptoss-vllm|gpt-oss-vllm)
            echo "gpt-oss-vllm"
            ;;
        12|kimi_ktransformers|kimi-ktransformers)
            echo "kimi-ktransformers"
            ;;
        13|kimi_sglang|kimi-sglang)
            echo "kimi-sglang"
            ;;
        14|kimi_vllm|kimi-vllm)
            echo "kimi-vllm"
            ;;
        15|ling_sglang|ling-sglang|ling26_sglang|ling26-sglang|ling_2_6_sglang|ling-2.6-sglang)
            echo "ling-sglang"
            ;;
        16|ling_transformers|ling-transformers|ling26_transformers|ling26-transformers|ling_2_6_transformers|ling-2.6-transformers)
            echo "ling-transformers"
            ;;
        17|ling_vllm|ling-vllm|ling26_vllm|ling26-vllm|ling_2_6_vllm|ling-2.6-vllm)
            echo "ling-vllm"
            ;;
        18|minimax_ktransformers|minimax-ktransformers)
            echo "minimax-ktransformers"
            ;;
        19|minimax_sglang|minimax-sglang)
            echo "minimax-sglang"
            ;;
        20|minimax_transformers|minimax-transformers)
            echo "minimax-transformers"
            ;;
        21|minimax_vllm|minimax-vllm)
            echo "minimax-vllm"
            ;;
        22|nemotron_sglang|nemotron-sglang)
            echo "nemotron-sglang"
            ;;
        23|nemotron_trtllm|nemotron-trtllm|nemotron_trt_llm|nemotron-trt-llm)
            echo "nemotron-trtllm"
            ;;
        24|nemotron_vllm|nemotron-vllm)
            echo "nemotron-vllm"
            ;;
        25|qwen3_ktransformers|qwen3-ktransformers)
            echo "qwen3-ktransformers"
            ;;
        26|qwen3_sglang|qwen3-sglang)
            echo "qwen3-sglang"
            ;;
        27|qwen3_transformers|qwen3-transformers)
            echo "qwen3-transformers"
            ;;
        28|qwen3_vllm|qwen3-vllm)
            echo "qwen3-vllm"
            ;;
        29|custom|custom_uv|custom-uv|env_custom_uv)
            echo "custom_uv"
            ;;
        30|custom_pip|custom-pip|env_custom_pip)
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

resolve_env_name() {
    local env_type="$1"

    if [ -z "$env_type" ]; then
        echo "custom_uv"
        return 0
    fi

    echo "$env_type"
}

# Check if being sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    BEING_SOURCED=true
else
    BEING_SOURCED=false
    print_error "This script must be sourced, not executed!"
    print_info "Use: source $0 [--auto] [env_name]"
    exit 1
fi

# Parse arguments
AUTO_MODE=false
ENV_TYPE=""

for arg in "$@"; do
    case $arg in
        --auto)
            AUTO_MODE=true
            ;;
        *)
            if [[ ! "$arg" =~ ^-- ]]; then
                ENV_TYPE="$arg"
            fi
            ;;
    esac
done

# Prompt for environment type if not provided and not in auto mode
if [ -z "$ENV_TYPE" ] && [ "$AUTO_MODE" = false ]; then
    echo ""
    print_info "Select ML environment type:"
    echo "1) DeepSeek-V3/V4/R1/OCR (KTransformers)"
    echo "2) DeepSeek-V3/V4/R1/OCR (LMDeploy)"
    echo "3) DeepSeek-V3/V4/R1/OCR (SGLang)"
    echo "4) DeepSeek-V3/V4/R1/OCR (vLLM)"
    echo "5) Gemma-4 (SGLang)"
    echo "6) Gemma-4 (vLLM)"
    echo "7) GLM-4/5 (SGLang)"
    echo "8) GLM-4/5 (Transformers)"
    echo "9) GLM-4/5 (vLLM)"
    echo "10) gpt-oss (Transformers)"
    echo "11) gpt-oss (vLLM)"
    echo "12) Kimi K2.X (KTransformers)"
    echo "13) Kimi K2.X (SGLang)"
    echo "14) Kimi K2.X (vLLM)"
    echo "15) Ling-2.6 (SGLang)"
    echo "16) Ling-2.6 (Transformers)"
    echo "17) Ling-2.6 (vLLM)"
    echo "18) MiniMax-M2.X (KTransformers)"
    echo "19) MiniMax-M2.X (SGLang)"
    echo "20) MiniMax-M2.X (Transformers)"
    echo "21) MiniMax-M2.X (vLLM)"
    echo "22) Nemotron-3 (SGLang)"
    echo "23) Nemotron-3 (TRT-LLM)"
    echo "24) Nemotron-3 (vLLM)"
    echo "25) Qwen3 (KTransformers)"
    echo "26) Qwen3 (SGLang)"
    echo "27) Qwen3 (Transformers)"
    echo "28) Qwen3 (vLLM)"
    echo "29) Custom (uv)"
    echo "30) Custom (pip)"
    echo ""
    while true; do
        read -p "Enter your choice (1-30): " choice
        if ENV_TYPE=$(resolve_env_type "$choice"); then
            break
        else
            print_error "Invalid choice. Please enter a number between 1 and 30."
        fi
    done
elif [ -z "$ENV_TYPE" ]; then
    # Default to GLM-4/5 (SGLang) in auto mode
    ENV_TYPE="glm_sglang"
fi

# Normalize environment type when provided directly
if [ -n "$ENV_TYPE" ]; then
    if ENV_TYPE_MAPPED=$(resolve_env_type "$ENV_TYPE"); then
        ENV_TYPE="$ENV_TYPE_MAPPED"
    fi
fi

if [[ "$ENV_TYPE" =~ ^[0-9]+$ ]]; then
    print_error "Invalid environment selection: $ENV_TYPE"
    return 1 2>/dev/null || exit 1
fi

# Set environment name based on type
ENV_NAME=$(resolve_env_name "$ENV_TYPE")

ENV_PATH="$HOME/env_${ENV_NAME}"

# Check if environment exists
if [ ! -d "$ENV_PATH" ]; then
    print_error "Environment '$ENV_NAME' not found at $ENV_PATH"
    print_info "Run 05_setup_env.sh first to create it"
    return 1 2>/dev/null || exit 1
fi

# Check if already in a virtual environment
if [ -n "$VIRTUAL_ENV" ]; then
    print_warning "Already in virtual environment: $VIRTUAL_ENV"
    if [ "$AUTO_MODE" = false ]; then
        read -p "Deactivate and switch to $ENV_NAME? (y/n): " SWITCH
    else
        SWITCH="y"
        print_info "Auto mode: switching environment"
    fi
    if [[ "$SWITCH" =~ ^[Yy]$ ]]; then
        deactivate
    else
        return 0
    fi
fi

# Check if activate_ml script exists, use it if available
if [ -f "$ENV_PATH/activate_ml" ]; then
    print_info "Using activate_ml script..."
    if ! source "$ENV_PATH/activate_ml"; then
        print_error "Failed to activate environment '$ENV_NAME' with $ENV_PATH/activate_ml"
        return 1 2>/dev/null || exit 1
    fi
elif [ -f "$ENV_PATH/bin/activate" ]; then
    # Fallback to manual activation
    print_info "Activating $ENV_NAME environment..."
    if ! source "$ENV_PATH/bin/activate"; then
        print_error "Failed to activate environment '$ENV_NAME' with $ENV_PATH/bin/activate"
        return 1 2>/dev/null || exit 1
    fi
    
    # Determine HF_PATH - check if already set, otherwise use default
    if [ -n "$HF_HOME" ]; then
        HF_PATH="$HF_HOME"
    else
        HF_PATH="/workspace/models/huggingface"
    fi
    
    # Set ML environment variables
    export HF_HOME="$HF_PATH"
    export HF_HUB_CACHE="$HF_PATH/hub"

    # Detect GPU architecture
    print_info "Detecting GPU architecture..."
    TORCH_CUDA_ARCH_LIST=""
    
    if command -v nvidia-smi &> /dev/null; then
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 | tr '[:lower:]' '[:upper:]')
        
        if [ -n "$GPU_NAME" ]; then
            print_info "Detected GPU: $GPU_NAME"
            
            # Determine architecture based on GPU model
            if [[ "$GPU_NAME" == *"V100"* ]]; then
                TORCH_CUDA_ARCH_LIST="7.0"
                print_info "  → $GPU_NAME (Volta) detected: sm_70"
                
            elif [[ "$GPU_NAME" == *"T4"* ]] || \
                 ([[ "$GPU_NAME" == *"RTX 5000"* ]] && [[ "$GPU_NAME" != *"ADA"* ]]) || \
                 ([[ "$GPU_NAME" == *"RTX 4000"* ]] && [[ "$GPU_NAME" != *"ADA"* ]]) || \
                 ([[ "$GPU_NAME" == *"RTX 6000"* ]] && [[ "$GPU_NAME" != *"ADA"* ]]); then
                TORCH_CUDA_ARCH_LIST="7.5"
                print_info "  → $GPU_NAME (Turing) detected: sm_75"
                
            elif [[ "$GPU_NAME" == *"A100"* ]] || [[ "$GPU_NAME" == *"A30"* ]]; then
                TORCH_CUDA_ARCH_LIST="8.0"
                print_info "  → $GPU_NAME (Ampere) detected: sm_80"
                
            elif [[ "$GPU_NAME" == *"RTX 3090"* ]] || [[ "$GPU_NAME" == *"3090"* ]] || \
                 [[ "$GPU_NAME" == *"RTX 3080"* ]] || [[ "$GPU_NAME" == *"3080"* ]] || \
                 [[ "$GPU_NAME" == *"RTX 3070"* ]] || [[ "$GPU_NAME" == *"3070"* ]] || \
                 [[ "$GPU_NAME" == *"RTX A6000"* ]] || [[ "$GPU_NAME" == *"A6000"* ]] || \
                 [[ "$GPU_NAME" == *"RTX A5000"* ]] || [[ "$GPU_NAME" == *"A5000"* ]] || \
                 [[ "$GPU_NAME" == *"RTX A4500"* ]] || [[ "$GPU_NAME" == *"A4500"* ]] || \
                 [[ "$GPU_NAME" == *"RTX A4000"* ]] || [[ "$GPU_NAME" == *"A4000"* ]] || \
                 [[ "$GPU_NAME" == *"RTX A2000"* ]] || [[ "$GPU_NAME" == *"A2000"* ]] || \
                 [[ "$GPU_NAME" == *"A10"* ]] || [[ "$GPU_NAME" == *"A40"* ]]; then
                TORCH_CUDA_ARCH_LIST="8.6"
                print_info "  → $GPU_NAME (Ampere) detected: sm_86"
                
            elif [[ "$GPU_NAME" == *"RTX 4090"* ]] || [[ "$GPU_NAME" == *"4090"* ]] || \
                 [[ "$GPU_NAME" == *"RTX 4070 TI"* ]] || [[ "$GPU_NAME" == *"4070 TI"* ]] || \
                 [[ "$GPU_NAME" == *"L40S"* ]] || [[ "$GPU_NAME" == *"L40"* ]] || [[ "$GPU_NAME" == *"L4"* ]] || \
                 ([[ "$GPU_NAME" == *"RTX 6000"* ]] && [[ "$GPU_NAME" == *"ADA"* ]]) || \
                 ([[ "$GPU_NAME" == *"RTX 5000"* ]] && [[ "$GPU_NAME" == *"ADA"* ]]) || \
                 ([[ "$GPU_NAME" == *"RTX 4000"* ]] && [[ "$GPU_NAME" == *"ADA"* ]]); then
                TORCH_CUDA_ARCH_LIST="8.9"
                print_info "  → $GPU_NAME (Ada Lovelace) detected: sm_89"
                
            elif [[ "$GPU_NAME" == *"H100"* ]] || [[ "$GPU_NAME" == *"H200"* ]] || [[ "$GPU_NAME" == *"GH200"* ]]; then
                TORCH_CUDA_ARCH_LIST="9.0"
                print_info "  → $GPU_NAME (Hopper) detected: sm_90"
                
            elif [[ "$GPU_NAME" == *"B200"* ]]; then
                TORCH_CUDA_ARCH_LIST="10.0"
                print_info "  → $GPU_NAME (Blackwell) detected: sm_100"
            
	    elif [[ "$GPU_NAME" == *"RTX 5090"* ]] || [[ "$GPU_NAME" == *"5090"* ]] || \
                ([[ "$GPU_NAME" == *"RTX PRO 6000"* ]] && [[ "$GPU_NAME" == *"BLACKWELL"* ]]); then
                TORCH_CUDA_ARCH_LIST="12.0"
                print_info "  → $GPU_NAME (Blackwell) detected: sm_120"
                
            else
                print_warning "  → Unknown GPU model, will use default PyTorch CUDA architectures"
            fi
            
            if [ -n "$TORCH_CUDA_ARCH_LIST" ]; then
                export TORCH_CUDA_ARCH_LIST="$TORCH_CUDA_ARCH_LIST"
                print_info "  → Set TORCH_CUDA_ARCH_LIST=$TORCH_CUDA_ARCH_LIST"
            fi
        else
            print_warning "Could not detect GPU name"
        fi
    else
        print_warning "nvidia-smi not found - no GPU detected"
    fi

    # CUDA paths if nvcc is available
    if command -v nvcc &> /dev/null; then
        export PATH="/usr/local/cuda/bin:$PATH"
        export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
    fi
else
    print_error "No activation script found for environment '$ENV_NAME'"
    print_info "Expected $ENV_PATH/activate_ml or $ENV_PATH/bin/activate"
    return 1 2>/dev/null || exit 1
fi

find_system_cuda_13_home() {
    local candidates=()

    if [ -n "${CUDA_HOME:-}" ]; then
        candidates+=("$CUDA_HOME")
    fi
    if [ -n "${CUDA_PATH:-}" ]; then
        candidates+=("$CUDA_PATH")
    fi

    candidates+=(
        /usr/local/cuda-13.0
        /usr/local/cuda-13
        /usr/local/cuda
    )

    local candidate release
    local seen=":"
    for candidate in "${candidates[@]}"; do
        [ -n "$candidate" ] || continue
        candidate="${candidate%/}"
        if [ -n "${VIRTUAL_ENV:-}" ] && [[ "$candidate" == "$VIRTUAL_ENV"* ]]; then
            continue
        fi
        case "$seen" in
            *":$candidate:"*) continue ;;
        esac
        seen+="$candidate:"

        [ -x "$candidate/bin/nvcc" ] || continue
        release=$("$candidate/bin/nvcc" --version 2>/dev/null | sed -n 's/.*release \([0-9][0-9]*\.[0-9]\).*/\1/p' | head -1)
        case "$release" in
            13.*) ;;
            *) continue ;;
        esac
        [ -f "$candidate/include/cuda_runtime_api.h" ] || continue
        [ -e "$candidate/lib64/libcudart.so" ] || [ -e "$candidate/lib/libcudart.so" ] || continue
        [ -e "$candidate/include/nv/target" ] || [ -e "$candidate/include/cccl/nv/target" ] || continue
        [ -e "$candidate/include/cuda/std/utility" ] || [ -e "$candidate/include/cccl/cuda/std/utility" ] || continue

        echo "$candidate"
        return 0
    done

    return 1
}

find_venv_cuda_13_home() {
    python - <<'PY'
import pathlib
import site
import sys

for site_dir in site.getsitepackages():
    candidate = pathlib.Path(site_dir) / "nvidia" / "cu13"
    if (candidate / "bin" / "nvcc").is_file():
        print(candidate)
        sys.exit(0)
sys.exit(1)
PY
}

setup_cuda_13_runtime() {
    local env_label="$1"
    CUDA_13_HOME=""
    CUDA_13_SOURCE=""
    if CUDA_13_HOME=$(find_system_cuda_13_home); then
        CUDA_13_SOURCE="system"
    elif CUDA_13_HOME=$(find_venv_cuda_13_home); then
        CUDA_13_SOURCE="virtualenv"
    fi

    if [ -n "$CUDA_13_HOME" ]; then
        export CUDA_HOME="$CUDA_13_HOME"
        export CUDA_PATH="$CUDA_13_HOME"
        prepend_env_path_once PATH "$CUDA_13_HOME/bin"
        prepend_env_path_once LD_LIBRARY_PATH "$CUDA_13_HOME/lib64"
        prepend_env_path_once LD_LIBRARY_PATH "$CUDA_13_HOME/lib"
        prepend_env_path_once LIBRARY_PATH "$CUDA_13_HOME/lib64"
        prepend_env_path_once LIBRARY_PATH "$CUDA_13_HOME/lib"
        if [ -d "$CUDA_13_HOME/include/cccl" ]; then
            prepend_env_path_once CPATH "$CUDA_13_HOME/include/cccl"
        fi
        print_info "$env_label CUDA toolkit: $CUDA_HOME ($CUDA_13_SOURCE)"
    else
        print_warning "$env_label CUDA 13 toolkit not found on the system or in the virtual environment."
        print_info "Run ./06_install_packages.sh --env $ENV_TYPE to install the required packages."
    fi
}

prepend_env_path_once() {
    local var_name="$1"
    local dir="$2"
    local current="${!var_name:-}"

    [ -n "$dir" ] || return 0
    case ":$current:" in
        *":$dir:"*) return 0 ;;
    esac

    if [ -n "$current" ]; then
        export "$var_name=$dir:$current"
    else
        export "$var_name=$dir"
    fi
}

case "$ENV_TYPE" in
    deepseek-sglang)
        setup_cuda_13_runtime "DeepSeek SGLang"
        ;;
    gemma-vllm)
        setup_cuda_13_runtime "Gemma vLLM"
        ;;
esac

export DG_JIT_CACHE_DIR="${VIRTUAL_ENV:-$ENV_PATH}/.cache/deep_gemm"
export FLASHINFER_WORKSPACE_BASE="${VIRTUAL_ENV:-$ENV_PATH}"
export SGLANG_DG_CACHE_DIR="${VIRTUAL_ENV:-$ENV_PATH}/.cache/deep_gemm"
export TORCH_EXTENSIONS_DIR="${VIRTUAL_ENV:-$ENV_PATH}/.cache/torch_extensions"
export TORCH_HOME="${VIRTUAL_ENV:-$ENV_PATH}/.cache/torch"
export TORCHINDUCTOR_CACHE_DIR="${VIRTUAL_ENV:-$ENV_PATH}/.cache/torchinductor"
export TRITON_CACHE_DIR="${VIRTUAL_ENV:-$ENV_PATH}/.cache/triton"
export TRITON_HOME="${VIRTUAL_ENV:-$ENV_PATH}"
export TVM_FFI_CACHE_DIR="${VIRTUAL_ENV:-$ENV_PATH}/.cache/tvm-ffi"
export VLLM_CACHE_ROOT="${VIRTUAL_ENV:-$ENV_PATH}/.cache/vllm"
export XDG_CACHE_HOME="${VIRTUAL_ENV:-$ENV_PATH}/.cache"

# Display activation info if not using activate_ml script
if [ ! -f "$ENV_PATH/activate_ml" ]; then
    echo ""
    print_info "✓ ML environment activated!"
    echo "  - Virtual env: $ENV_PATH"
    echo "  - Python: $(which python) ($(python --version 2>&1))"
    echo "  - HF_HOME: $HF_HOME"
    echo "  - HF_HUB_CACHE: $HF_HUB_CACHE"
    echo "  - CPU threads: $OMP_NUM_THREADS"
    if [ -n "$TORCH_CUDA_ARCH_LIST" ]; then
        echo "  - TORCH_CUDA_ARCH_LIST: $TORCH_CUDA_ARCH_LIST"
    fi
    if command -v nvcc &> /dev/null; then
        echo "  - CUDA: $(nvcc --version | grep release | awk '{print $6}')"
    fi
fi

echo ""
print_info "To deactivate: deactivate"
print_info "To install or configure environment packages: ./06_install_packages.sh"
