#!/bin/bash

# Script: launch_env.sh
# Purpose: Activate ML environment with all optimizations
# Usage: source launch_env.sh [--auto] [ENV_NAME|1-66]

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

prepend_env_path_once() {
    local var_name="$1"
    local dir="$2"
    local current="${!var_name:-}"

    [ -n "$dir" ] || return 0
    [ -d "$dir" ] || return 0
    case ":$current:" in
        *":$dir:"*) return 0 ;;
    esac

    if [ -n "$current" ]; then
        export "$var_name=$dir:$current"
    else
        export "$var_name=$dir"
    fi
}

cuda_home_is_valid() {
    local cuda_home="$1"

    [ -n "$cuda_home" ] || return 1
    cuda_home="${cuda_home%/}"
    [ -d "$cuda_home" ] || return 1
    [ -x "$cuda_home/bin/nvcc" ] || return 1
}

cuda_version_for_home() {
    local cuda_home="$1"

    cuda_home="${cuda_home%/}"
    if ! cuda_home_is_valid "$cuda_home"; then
        echo ""
        return 1
    fi

    "$cuda_home/bin/nvcc" --version 2>/dev/null | sed -n 's/.*release \([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -1
}

detect_default_cuda_home() {
    local candidates=()
    local nvcc_path=""

    candidates+=("/usr/local/cuda")
    if [ -n "${CUDA_HOME:-}" ]; then
        candidates+=("$CUDA_HOME")
    fi
    if [ -n "${CUDA_PATH:-}" ]; then
        candidates+=("$CUDA_PATH")
    fi
    if nvcc_path=$(command -v nvcc 2>/dev/null); then
        candidates+=("$(cd -- "$(dirname -- "$nvcc_path")/.." && pwd)")
    fi

    local candidate
    local seen=":"
    for candidate in "${candidates[@]}"; do
        [ -n "$candidate" ] || continue
        candidate="${candidate%/}"
        case "$seen" in
            *":$candidate:"*) continue ;;
        esac
        seen+="$candidate:"

        if cuda_home_is_valid "$candidate"; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

apply_env_cuda_selection() {
    local cuda_config="$ENV_PATH/.cuda_env"
    CUDA_ENV_MODE="bashrc"
    CUDA_ENV_HOME=""
    CUDA_ENV_VERSION=""

    if [ -f "$cuda_config" ]; then
        # shellcheck source=/dev/null
        source "$cuda_config"
    fi

    case "${CUDA_ENV_MODE:-bashrc}" in
        explicit)
            if ! cuda_home_is_valid "$CUDA_ENV_HOME"; then
                print_error "Selected CUDA toolkit is not available: $CUDA_ENV_HOME"
                print_error "Install CUDA first with ./03_install_cuda.sh or rerun 05_setup_env.sh to select another CUDA version."
                return 1
            fi
            export CUDA_HOME="${CUDA_ENV_HOME%/}"
            export CUDA_PATH="$CUDA_HOME"
            export ML_ENV_CUDA_SOURCE="environment selection"
            ;;
        bashrc|"")
            local default_cuda_home
            if ! default_cuda_home=$(detect_default_cuda_home); then
                print_error "No CUDA toolkit detected. Install CUDA first with ./03_install_cuda.sh."
                return 1
            fi
            export CUDA_HOME="${default_cuda_home%/}"
            export CUDA_PATH="$CUDA_HOME"
            export CUDA_ENV_MODE="bashrc"
            export ML_ENV_CUDA_SOURCE="bashrc default"
            ;;
        *)
            print_error "Invalid CUDA_ENV_MODE in $cuda_config: $CUDA_ENV_MODE"
            return 1
            ;;
    esac

    prepend_env_path_once PATH "$CUDA_HOME/bin"
    prepend_env_path_once LD_LIBRARY_PATH "$CUDA_HOME/lib64"
    prepend_env_path_once LD_LIBRARY_PATH "$CUDA_HOME/lib"
    prepend_env_path_once LIBRARY_PATH "$CUDA_HOME/lib64"
    prepend_env_path_once LIBRARY_PATH "$CUDA_HOME/lib"
    if [ -d "$CUDA_HOME/include/cccl" ]; then
        prepend_env_path_once CPATH "$CUDA_HOME/include/cccl"
    fi

    export ML_ENV_CUDA_APPLIED=1
    export ML_ENV_CUDA_HOME="$CUDA_HOME"
    export ML_ENV_CUDA_VERSION
    ML_ENV_CUDA_VERSION=$(cuda_version_for_home "$CUDA_HOME")
    print_info "CUDA toolkit: $ML_ENV_CUDA_HOME (${ML_ENV_CUDA_VERSION:-unknown}, $ML_ENV_CUDA_SOURCE)"
}

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
        5|cohere_transformers|cohere-transformers)
            echo "cohere-transformers"
            ;;
        6|cohere_vllm|cohere-vllm)
            echo "cohere-vllm"
            ;;
        7|deepseek_ktransformers|deepseek-ktransformers)
            echo "deepseek-ktransformers"
            ;;
        8|deepseek_lmdeploy|deepseek-lmdeploy)
            echo "deepseek-lmdeploy"
            ;;
        9|deepseek_sglang|deepseek-sglang)
            echo "deepseek-sglang"
            ;;
        10|deepseek_vllm|deepseek-vllm)
            echo "deepseek-vllm"
            ;;
        11|gemma_sglang|gemma-sglang|gemma4_sglang|gemma4-sglang|gemma_4_sglang|gemma-4-sglang)
            echo "gemma-sglang"
            ;;
        12|gemma_vllm|gemma-vllm|gemma4_vllm|gemma4-vllm|gemma_4_vllm|gemma-4-vllm)
            echo "gemma-vllm"
            ;;
        13|glm_ktransformers|glm-ktransformers)
            echo "glm-ktransformers"
            ;;
        14|glm_sglang|glm-sglang)
            echo "glm-sglang"
            ;;
        15|glm_transformers|glm-transformers)
            echo "glm-transformers"
            ;;
        16|glm_vllm|glm-vllm)
            echo "glm-vllm"
            ;;
        17|gptoss_transformers|gpt-oss_transformers|gptoss-transformers|gpt-oss-transformers)
            echo "gpt-oss-transformers"
            ;;
        18|gptoss_vllm|gpt-oss_vllm|vllm_gptoss|gptoss-vllm|gpt-oss-vllm)
            echo "gpt-oss-vllm"
            ;;
        19|inclusionai_sglang|inclusionai-sglang)
            echo "inclusionai-sglang"
            ;;
        20|inclusionai_transformers|inclusionai-transformers)
            echo "inclusionai-transformers"
            ;;
        21|inclusionai_vllm|inclusionai-vllm)
            echo "inclusionai-vllm"
            ;;
        22|intel_vllm|intel-vllm)
            echo "intel-vllm"
            ;;
        23|kimi_ktransformers|kimi-ktransformers)
            echo "kimi-ktransformers"
            ;;
        24|kimi_sglang|kimi-sglang)
            echo "kimi-sglang"
            ;;
        25|kimi_vllm|kimi-vllm)
            echo "kimi-vllm"
            ;;
        26|laguna_sglang|laguna-sglang)
            echo "laguna-sglang"
            ;;
        27|laguna_trtllm|laguna-trtllm|laguna_trt_llm|laguna-trt-llm)
            echo "laguna-trtllm"
            ;;
        28|laguna_vllm|laguna-vllm)
            echo "laguna-vllm"
            ;;
        29|liquidai_sglang|liquidai-sglang)
            echo "liquidai-sglang"
            ;;
        30|liquidai_transformers|liquidai-transformers)
            echo "liquidai-transformers"
            ;;
        31|liquidai_vllm|liquidai-vllm)
            echo "liquidai-vllm"
            ;;
        32|microsoft_vllm|microsoft-vllm)
            echo "microsoft-vllm"
            ;;
        33|minimax_ktransformers|minimax-ktransformers)
            echo "minimax-ktransformers"
            ;;
        34|minimax_sglang|minimax-sglang)
            echo "minimax-sglang"
            ;;
        35|minimax_transformers|minimax-transformers)
            echo "minimax-transformers"
            ;;
        36|minimax_vllm|minimax-vllm)
            echo "minimax-vllm"
            ;;
        37|mistralai_transformers|mistralai-transformers)
            echo "mistralai-transformers"
            ;;
        38|mistralai_vllm|mistralai-vllm)
            echo "mistralai-vllm"
            ;;
        39|nanbeige_sglang|nanbeige-sglang)
            echo "nanbeige-sglang"
            ;;
        40|nanbeige_transformers|nanbeige-transformers)
            echo "nanbeige-transformers"
            ;;
        41|nanbeige_vllm|nanbeige-vllm)
            echo "nanbeige-vllm"
            ;;
        42|nemotron_sglang|nemotron-sglang)
            echo "nemotron-sglang"
            ;;
        43|nemotron_trtllm|nemotron-trtllm|nemotron_trt_llm|nemotron-trt-llm)
            echo "nemotron-trtllm"
            ;;
        44|nemotron_vllm|nemotron-vllm)
            echo "nemotron-vllm"
            ;;
        45|nvidia_vllm|nvidia-vllm)
            echo "nvidia-vllm"
            ;;
        46|poolside_sglang|poolside-sglang)
            echo "poolside-sglang"
            ;;
        47|poolside_transformers|poolside-transformers)
            echo "poolside-transformers"
            ;;
        48|poolside_vllm|poolside-vllm)
            echo "poolside-vllm"
            ;;
        49|primeintellect_vllm|primeintellect-vllm)
            echo "primeintellect-vllm"
            ;;
        50|qwen_ktransformers|qwen-ktransformers)
            echo "qwen-ktransformers"
            ;;
        51|qwen_sglang|qwen-sglang)
            echo "qwen-sglang"
            ;;
        52|qwen_transformers|qwen-transformers)
            echo "qwen-transformers"
            ;;
        53|qwen_vllm|qwen-vllm)
            echo "qwen-vllm"
            ;;
        54|redhat_vllm|redhat-vllm)
            echo "redhat-vllm"
            ;;
        55|stepfun_sglang|stepfun-sglang)
            echo "stepfun-sglang"
            ;;
        56|stepfun_transformers|stepfun-transformers)
            echo "stepfun-transformers"
            ;;
        57|stepfun_vllm|stepfun-vllm)
            echo "stepfun-vllm"
            ;;
        58|zyphra_transformers|zyphra-transformers)
            echo "zyphra-transformers"
            ;;
        59|zyphra_vllm|zyphra-vllm)
            echo "zyphra-vllm"
            ;;
        60|zyphra_legacy_transformers|zyphra-legacy-transformers)
            echo "zyphra-legacy-transformers"
            ;;
        61|zyphra_legacy_vllm|zyphra-legacy-vllm)
            echo "zyphra-legacy-vllm"
            ;;
        62|custom|custom_uv|custom-uv|env_custom_uv)
            echo "custom_uv"
            ;;
        63|custom_pip|custom-pip|env_custom_pip)
            echo "custom_pip"
            ;;
        *)
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
    print_error "Use: source $0 [--auto] [ENV_NAME|1-66]"
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
    echo "1) AllenAI (Transformers)"
    echo "2) AllenAI (vLLM)"
    echo "3) Arcee (Transformers)"
    echo "4) Arcee (vLLM)"
    echo "5) Cohere (Transformers)"
    echo "6) Cohere (vLLM)"
    echo "7) DeepSeek (KTransformers)"
    echo "8) DeepSeek (LMDeploy)"
    echo "9) DeepSeek (SGLang)"
    echo "10) DeepSeek (vLLM)"
    echo "11) Gemma (SGLang)"
    echo "12) Gemma (vLLM)"
    echo "13) GLM (KTransformers)"
    echo "14) GLM (SGLang)"
    echo "15) GLM (Transformers)"
    echo "16) GLM (vLLM)"
    echo "17) gpt-oss (Transformers)"
    echo "18) gpt-oss (vLLM)"
    echo "19) InclusionAI (SGLang)"
    echo "20) InclusionAI (Transformers)"
    echo "21) InclusionAI (vLLM)"
    echo "22) Intel (vLLM)"
    echo "23) Kimi (KTransformers)"
    echo "24) Kimi (SGLang)"
    echo "25) Kimi (vLLM)"
    echo "26) Laguna (SGLang)"
    echo "27) Laguna (TRT-LLM)"
    echo "28) Laguna (vLLM)"
    echo "29) LiquidAI (SGLang)"
    echo "30) LiquidAI (Transformers)"
    echo "31) LiquidAI (vLLM)"
    echo "32) Microsoft (vLLM)"
    echo "33) MiniMax (KTransformers)"
    echo "34) MiniMax (SGLang)"
    echo "35) MiniMax (Transformers)"
    echo "36) MiniMax (vLLM)"
    echo "37) MistralAI (Transformers)"
    echo "38) MistralAI (vLLM)"
    echo "39) Nanbeige (SGLang)"
    echo "40) Nanbeige (Transformers)"
    echo "41) Nanbeige (vLLM)"
    echo "42) Nemotron (SGLang)"
    echo "43) Nemotron (TRT-LLM)"
    echo "44) Nemotron (vLLM)"
    echo "45) NVIDIA (vLLM)"
    echo "46) Poolside (SGLang)"
    echo "47) Poolside (Transformers)"
    echo "48) Poolside (vLLM)"
    echo "49) PrimeIntellect (vLLM)"
    echo "50) Qwen (KTransformers)"
    echo "51) Qwen (SGLang)"
    echo "52) Qwen (Transformers)"
    echo "53) Qwen (vLLM)"
    echo "54) RedHat (vLLM)"
    echo "55) StepFun (SGLang)"
    echo "56) StepFun (Transformers)"
    echo "57) StepFun (vLLM)"
    echo "58) Zyphra (Transformers)"
    echo "59) Zyphra (vLLM)"
    echo "60) Zyphra Legacy (Transformers)"
    echo "61) Zyphra Legacy (vLLM)"
    echo "62) Custom (uv)"
    echo "63) Custom (pip)"
    echo ""
    while true; do
        read -p "Enter your choice (1-63): " choice
        if ENV_TYPE=$(resolve_env_type "$choice"); then
            break
        else
            print_error "Invalid choice. Please enter a number between 1 and 66."
        fi
    done
elif [ -z "$ENV_TYPE" ]; then
    # Default to GLM (SGLang) in auto mode
    ENV_TYPE="glm_sglang"
fi

# Normalize and validate the selected managed environment.
if [ -n "$ENV_TYPE" ]; then
    if ! ENV_TYPE_MAPPED=$(resolve_env_type "$ENV_TYPE"); then
        print_error "Invalid environment selection: $ENV_TYPE. Choose a listed environment name or a number from 1 to 65."
        return 1
    fi
    ENV_TYPE="$ENV_TYPE_MAPPED"
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

else
    print_error "No activation script found for environment '$ENV_NAME'"
    print_info "Expected $ENV_PATH/activate_ml or $ENV_PATH/bin/activate"
    return 1 2>/dev/null || exit 1
fi

if [ "${ML_ENV_CUDA_APPLIED:-}" != "1" ]; then
    if ! apply_env_cuda_selection; then
        return 1 2>/dev/null || exit 1
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
    if [ -n "${ML_ENV_CUDA_HOME:-}" ]; then
        echo "  - CUDA toolkit: $ML_ENV_CUDA_HOME (${ML_ENV_CUDA_VERSION:-unknown}, ${ML_ENV_CUDA_SOURCE:-configured})"
    elif command -v nvcc &> /dev/null; then
        echo "  - CUDA: $(nvcc --version | grep release | awk '{print $6}')"
    fi
fi

echo ""
print_info "To deactivate: deactivate"
print_info "To install or configure environment packages: ./06_install_packages.sh"
