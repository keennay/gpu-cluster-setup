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
        4|glm_sglang|glm45-sglang)
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
        19|custom|custom_uv|custom-uv|custom_uv_env)
            echo "custom_uv"
            ;;
        20|custom_pip|custom-pip|custom_pip_env)
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
    echo "1) DeepSeek-V3.X/R1/OCR (LMDeploy)"
    echo "2) DeepSeek-V3.X/R1/OCR (SGLang)"
    echo "3) DeepSeek-V3.X/R1/OCR (vLLM)"
    echo "4) GLM 4.X (SGLang)"
    echo "5) GLM 4.X (Transformers)"
    echo "6) GLM 4.X (vLLM)"
    echo "7) gpt-oss (Transformers)"
    echo "8) gpt-oss (vLLM)"
    echo "9) Kimi K2.X (KTransformers)"
    echo "10) Kimi K2.X (SGLang)"
    echo "11) Kimi K2.X (vLLM)"
    echo "12) MiniMax-M2.X (KTransformers)"
    echo "13) MiniMax-M2.X (SGLang)"
    echo "14) MiniMax-M2.X (Transformers)"
    echo "15) MiniMax-M2.X (vLLM)"
    echo "16) Qwen3 (SGLang)"
    echo "17) Qwen3 (Transformers)"
    echo "18) Qwen3 (vLLM)"
    echo "19) Custom (uv)"
    echo "20) Custom (pip)"
    echo ""
    while true; do
        read -p "Enter your choice (1-20): " choice
        if ENV_TYPE=$(resolve_env_type "$choice"); then
            break
        else
            print_error "Invalid choice. Please enter a number between 1 and 20."
        fi
    done
elif [ -z "$ENV_TYPE" ]; then
    # Default to GLM 4.X (SGLang) in auto mode
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

ENV_PATH="$HOME/${ENV_NAME}_env"

# Check if environment exists
if [ ! -d "$ENV_PATH" ]; then
    print_error "Environment '$ENV_NAME' not found at $ENV_PATH"
    print_info "Run 03_setup_env.sh first to create it"
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
    export HUGGINGFACE_HUB_CACHE="$HF_PATH"

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

# Display activation info if not using activate_ml script
if [ ! -f "$ENV_PATH/activate_ml" ]; then
    echo ""
    print_info "✓ ML environment activated!"
    echo "  - Virtual env: $ENV_PATH"
    echo "  - Python: $(which python) ($(python --version 2>&1))"
    echo "  - HF_HOME: $HF_HOME"
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
print_info "To check packages: ./04_check_ml_packages.sh"
