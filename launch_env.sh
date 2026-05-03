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
        1|deepseek_lmdeploy|deepseek-lmdeploy)
            echo "deepseek-lmdeploy"
            ;;
        2|deepseek_sglang|deepseek-sglang)
            echo "deepseek-sglang"
            ;;
        3|deepseek_vllm|deepseek-vllm)
            echo "deepseek-vllm"
            ;;
        4|gemma_sglang|gemma-sglang|gemma4_sglang|gemma4-sglang|gemma_4_sglang|gemma-4-sglang)
            echo "gemma-sglang"
            ;;
        5|gemma_vllm|gemma-vllm|gemma4_vllm|gemma4-vllm|gemma_4_vllm|gemma-4-vllm)
            echo "gemma-vllm"
            ;;
        6|glm_sglang|glm-sglang|glm45-sglang)
            echo "glm-sglang"
            ;;
        7|glm_transformers|glm-transformers)
            echo "glm-transformers"
            ;;
        8|glm_vllm|glm-vllm)
            echo "glm-vllm"
            ;;
        9|gptoss_transformers|gpt-oss_transformers|gptoss-transformers|gpt-oss-transformers)
            echo "gpt-oss-transformers"
            ;;
        10|gptoss_vllm|gpt-oss_vllm|vllm_gptoss|gptoss-vllm|gpt-oss-vllm)
            echo "gpt-oss-vllm"
            ;;
        11|kimi_ktransformers|kimi-ktransformers)
            echo "kimi-ktransformers"
            ;;
        12|kimi_sglang|kimi-sglang)
            echo "kimi-sglang"
            ;;
        13|kimi_vllm|kimi-vllm)
            echo "kimi-vllm"
            ;;
        14|ling_sglang|ling-sglang|ling26_sglang|ling26-sglang|ling_2_6_sglang|ling-2.6-sglang)
            echo "ling-sglang"
            ;;
        15|ling_transformers|ling-transformers|ling26_transformers|ling26-transformers|ling_2_6_transformers|ling-2.6-transformers)
            echo "ling-transformers"
            ;;
        16|ling_vllm|ling-vllm|ling26_vllm|ling26-vllm|ling_2_6_vllm|ling-2.6-vllm)
            echo "ling-vllm"
            ;;
        17|minimax_ktransformers|minimax-ktransformers)
            echo "minimax-ktransformers"
            ;;
        18|minimax_sglang|minimax-sglang)
            echo "minimax-sglang"
            ;;
        19|minimax_transformers|minimax-transformers)
            echo "minimax-transformers"
            ;;
        20|minimax_vllm|minimax-vllm)
            echo "minimax-vllm"
            ;;
        21|nemotron_sglang|nemotron-sglang)
            echo "nemotron-sglang"
            ;;
        22|nemotron_trtllm|nemotron-trtllm|nemotron_trt_llm|nemotron-trt-llm)
            echo "nemotron-trtllm"
            ;;
        23|nemotron_vllm|nemotron-vllm)
            echo "nemotron-vllm"
            ;;
        24|qwen3_sglang|qwen3-sglang)
            echo "qwen3-sglang"
            ;;
        25|qwen3_transformers|qwen3-transformers)
            echo "qwen3-transformers"
            ;;
        26|qwen3_vllm|qwen3-vllm)
            echo "qwen3-vllm"
            ;;
        27|custom|custom_uv|custom-uv|env_custom_uv)
            echo "custom_uv"
            ;;
        28|custom_pip|custom-pip|env_custom_pip)
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
    echo "1) DeepSeek-V3/V4/R1/OCR (LMDeploy)"
    echo "2) DeepSeek-V3/V4/R1/OCR (SGLang)"
    echo "3) DeepSeek-V3/V4/R1/OCR (vLLM)"
    echo "4) Gemma-4 (SGLang)"
    echo "5) Gemma-4 (vLLM)"
    echo "6) GLM-4/5 (SGLang)"
    echo "7) GLM-4/5 (Transformers)"
    echo "8) GLM-4/5 (vLLM)"
    echo "9) gpt-oss (Transformers)"
    echo "10) gpt-oss (vLLM)"
    echo "11) Kimi K2.X (KTransformers)"
    echo "12) Kimi K2.X (SGLang)"
    echo "13) Kimi K2.X (vLLM)"
    echo "14) Ling-2.6 (SGLang)"
    echo "15) Ling-2.6 (Transformers)"
    echo "16) Ling-2.6 (vLLM)"
    echo "17) MiniMax-M2.X (KTransformers)"
    echo "18) MiniMax-M2.X (SGLang)"
    echo "19) MiniMax-M2.X (Transformers)"
    echo "20) MiniMax-M2.X (vLLM)"
    echo "21) Nemotron-3 (SGLang)"
    echo "22) Nemotron-3 (TRT-LLM)"
    echo "23) Nemotron-3 (vLLM)"
    echo "24) Qwen3 (SGLang)"
    echo "25) Qwen3 (Transformers)"
    echo "26) Qwen3 (vLLM)"
    echo "27) Custom (uv)"
    echo "28) Custom (pip)"
    echo ""
    while true; do
        read -p "Enter your choice (1-28): " choice
        if ENV_TYPE=$(resolve_env_type "$choice"); then
            break
        else
            print_error "Invalid choice. Please enter a number between 1 and 28."
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
    return 1
fi

# Set environment name based on type
ENV_NAME=$(resolve_env_name "$ENV_TYPE")

ENV_PATH="$HOME/env_${ENV_NAME}"

# Check if environment exists
if [ ! -d "$ENV_PATH" ]; then
    print_error "Environment '$ENV_NAME' not found at $ENV_PATH"
    print_info "Run 05_setup_env.sh first to create it"
    return 1
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
    source "$ENV_PATH/activate_ml"
else
    # Fallback to manual activation
    print_info "Activating $ENV_NAME environment..."
    source "$ENV_PATH/bin/activate"
    
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
fi

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
