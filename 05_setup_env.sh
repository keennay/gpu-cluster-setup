#!/bin/bash

# Script: 05_setup_env.sh
# Purpose: Create ML virtual environment and set up environment variables
# Usage: source 05_setup_env.sh [--auto] [ENV_NAME|1-65]

# Source bashrc to ensure environment is properly loaded
if [ -f "$HOME/.bashrc" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.bashrc"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_command() { echo -e "${BLUE}[RUN]${NC} $1"; }

fail_script() {
    local message="$1"
    print_error "$message"
    if [ "$BEING_SOURCED" = false ]; then
        exit 1
    else
        return 1
    fi
}

run_env_uv_pip_install() {
    local cmd=(uv pip install)
    cmd+=("$@")

    print_command "VIRTUAL_ENV=$ENV_PATH PATH=$ENV_PATH/bin:\$PATH $(printf '%q ' "${cmd[@]}")"
    VIRTUAL_ENV="$ENV_PATH" PATH="$ENV_PATH/bin:$PATH" "${cmd[@]}"
}

run_env_pip_install() {
    local cmd=(python -m pip install)
    cmd+=("$@")

    print_command "VIRTUAL_ENV=$ENV_PATH PATH=$ENV_PATH/bin:\$PATH $(printf '%q ' "${cmd[@]}")"
    VIRTUAL_ENV="$ENV_PATH" PATH="$ENV_PATH/bin:$PATH" "${cmd[@]}"
}

uses_pip_venv() {
    case "$ENV_TYPE" in
        deepseek-ktransformers|glm-ktransformers|kimi-ktransformers|minimax-ktransformers|nanbeige-vllm|qwen-ktransformers|zyphra-vllm|zyphra-legacy-vllm|custom_pip)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

environment_is_usable() {
    [ -f "$ENV_PATH/pyvenv.cfg" ] || return 1
    [ -x "$ENV_PATH/bin/python" ] || return 1
    "$ENV_PATH/bin/python" -c 'import sys' >/dev/null 2>&1 || return 1

    if ! uses_pip_venv; then
        [ -x "$ENV_PATH/bin/python3" ] || return 1
    fi
}

install_huggingface_hub() {
    print_info "Installing Hugging Face Hub Python library into $ENV_NAME..."
    if uses_pip_venv; then
        run_env_pip_install -U pip huggingface_hub || return 1
    else
        run_env_uv_pip_install -U huggingface_hub || return 1
    fi

    VIRTUAL_ENV="$ENV_PATH" PATH="$ENV_PATH/bin:$PATH" python - <<'PY' || return 1
from importlib.metadata import version
import shutil

import huggingface_hub

print(f"huggingface_hub {version('huggingface_hub')} installed")
if shutil.which("hf") is None:
    raise SystemExit("hf CLI was not found on PATH")
PY

    VIRTUAL_ENV="$ENV_PATH" PATH="$ENV_PATH/bin:$PATH" hf --help >/dev/null || return 1
    print_info "✓ Hugging Face Hub Python library and hf CLI installed"
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
        58|zlab_sglang|z_lab_sglang|z-lab_sglang|zlab-sglang|z-lab-sglang)
            echo "z-lab-sglang"
            ;;
        59|zlab_vllm|z_lab_vllm|z-lab_vllm|zlab-vllm|z-lab-vllm)
            echo "z-lab-vllm"
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

resolve_env_name() {
    local env_type="${1#env_}"

    if [ -z "$env_type" ]; then
        env_type="custom_uv"
    fi

    echo "env_$env_type"
}

CUDA_CANDIDATE_VERSIONS=()
CUDA_CANDIDATE_HOMES=()
SELECTED_CUDA_MODE=""
SELECTED_CUDA_HOME=""
SELECTED_CUDA_VERSION=""

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

detect_bashrc_cuda_home() {
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

collect_cuda_candidates() {
    CUDA_CANDIDATE_VERSIONS=()
    CUDA_CANDIDATE_HOMES=()

    local candidate_lines=()
    local cuda_dir
    for cuda_dir in /usr/local/cuda-*; do
        [ -d "$cuda_dir" ] || continue

        local dir_version=${cuda_dir##*/cuda-}
        [[ "$dir_version" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]] || continue
        cuda_home_is_valid "$cuda_dir" || continue

        local actual_version
        actual_version=$(cuda_version_for_home "$cuda_dir")
        if [ -n "$actual_version" ]; then
            candidate_lines+=("${actual_version}	${cuda_dir}")
        fi
    done

    [ ${#candidate_lines[@]} -gt 0 ] || return 0

    local version
    local path
    while IFS=$'\t' read -r version path; do
        if [ -n "$version" ] && [ -n "$path" ]; then
            CUDA_CANDIDATE_VERSIONS+=("$version")
            CUDA_CANDIDATE_HOMES+=("$path")
        fi
    done < <(printf "%s\n" "${candidate_lines[@]}" | awk '!seen[$1]++' | sort -V -k1,1)
}

select_cuda_for_env() {
    collect_cuda_candidates

    local bashrc_cuda_home=""
    local bashrc_cuda_version=""
    if bashrc_cuda_home=$(detect_bashrc_cuda_home); then
        bashrc_cuda_version=$(cuda_version_for_home "$bashrc_cuda_home")
    fi

    if [ -z "$bashrc_cuda_home" ] && [ ${#CUDA_CANDIDATE_HOMES[@]} -eq 0 ]; then
        fail_script "No CUDA toolkit detected. Install CUDA first with ./03_install_cuda.sh before setting up an ML environment."
        return 1
    fi

    if [ "$AUTO_MODE" = true ]; then
        if [ -n "$bashrc_cuda_home" ]; then
            SELECTED_CUDA_MODE="bashrc"
            SELECTED_CUDA_HOME=""
            SELECTED_CUDA_VERSION="$bashrc_cuda_version"
            print_info "Auto mode: using default bashrc CUDA for $ENV_NAME (CUDA $SELECTED_CUDA_VERSION at $bashrc_cuda_home)"
        else
            local last_index=$(( ${#CUDA_CANDIDATE_HOMES[@]} - 1 ))
            SELECTED_CUDA_MODE="explicit"
            SELECTED_CUDA_HOME="${CUDA_CANDIDATE_HOMES[$last_index]}"
            SELECTED_CUDA_VERSION="${CUDA_CANDIDATE_VERSIONS[$last_index]}"
            print_info "Auto mode: using CUDA $SELECTED_CUDA_VERSION for $ENV_NAME ($SELECTED_CUDA_HOME)"
        fi
        return 0
    fi

    echo ""
    print_info "Select CUDA toolkit for environment '$ENV_NAME':"

    local option_modes=()
    local option_homes=()
    local option_versions=()
    local option=1

    if [ -n "$bashrc_cuda_home" ]; then
        echo "  $option) Use default bashrc CUDA (CUDA $bashrc_cuda_version at $bashrc_cuda_home)"
        option_modes+=("bashrc")
        option_homes+=("")
        option_versions+=("$bashrc_cuda_version")
        option=$((option + 1))
    fi

    local index
    for index in "${!CUDA_CANDIDATE_HOMES[@]}"; do
        echo "  $option) CUDA ${CUDA_CANDIDATE_VERSIONS[$index]} - ${CUDA_CANDIDATE_HOMES[$index]}"
        option_modes+=("explicit")
        option_homes+=("${CUDA_CANDIDATE_HOMES[$index]}")
        option_versions+=("${CUDA_CANDIDATE_VERSIONS[$index]}")
        option=$((option + 1))
    done

    local max_choice=${#option_modes[@]}
    local cuda_choice=""
    read -r -p "Enter choice (1-$max_choice): " cuda_choice
    while ! [[ "$cuda_choice" =~ ^[0-9]+$ ]] || [ "$cuda_choice" -lt 1 ] || [ "$cuda_choice" -gt "$max_choice" ]; do
        read -r -p "Please enter a number from 1 to $max_choice: " cuda_choice
    done

    local selected_index=$((cuda_choice - 1))
    SELECTED_CUDA_MODE="${option_modes[$selected_index]}"
    SELECTED_CUDA_HOME="${option_homes[$selected_index]}"
    SELECTED_CUDA_VERSION="${option_versions[$selected_index]}"

    if [ "$SELECTED_CUDA_MODE" = "bashrc" ]; then
        print_info "Environment '$ENV_NAME' will use the default bashrc CUDA (CUDA $SELECTED_CUDA_VERSION)."
    else
        print_info "Environment '$ENV_NAME' will use CUDA $SELECTED_CUDA_VERSION at $SELECTED_CUDA_HOME."
    fi
}

write_cuda_env_config() {
    cat > "$ENV_PATH/.cuda_env" << EOF
# CUDA toolkit selection for this ML environment.
CUDA_ENV_MODE="$SELECTED_CUDA_MODE"
CUDA_ENV_HOME="$SELECTED_CUDA_HOME"
CUDA_ENV_VERSION="$SELECTED_CUDA_VERSION"
EOF
}

# Check if being sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    BEING_SOURCED=true
else
    BEING_SOURCED=false
fi

# Parse arguments
AUTO_MODE=false
ENV_TYPE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto)
            AUTO_MODE=true
            shift
            ;;
        -*)
            fail_script "Unknown option: $1"
            if [ "$BEING_SOURCED" = true ]; then
                return 1
            fi
            ;;
        *)
            if [ -n "$ENV_TYPE" ]; then
                fail_script "Only one environment may be specified."
                if [ "$BEING_SOURCED" = true ]; then
                    return 1
                fi
            fi
            ENV_TYPE="$1"
            shift
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
    echo "58) z-lab (SGLang)"
    echo "59) z-lab (vLLM)"
    echo "60) Zyphra (Transformers)"
    echo "61) Zyphra (vLLM)"
    echo "62) Zyphra Legacy (Transformers)"
    echo "63) Zyphra Legacy (vLLM)"
    echo "64) Custom (uv)"
    echo "65) Custom (pip)"
    echo ""
    while true; do
        read -r -p "Enter your choice (1-65): " choice
        if ENV_TYPE=$(resolve_env_type "$choice"); then
            break
        else
            print_error "Invalid choice. Please enter a number between 1 and 65."
        fi
    done
elif [ -z "$ENV_TYPE" ]; then
    # Default to GLM (SGLang) in auto mode
    ENV_TYPE="glm_sglang"
fi

# Normalize and validate the selected managed environment.
if [ -n "$ENV_TYPE" ]; then
    if ! ENV_TYPE_MAPPED=$(resolve_env_type "$ENV_TYPE"); then
        fail_script "Invalid environment selection: $ENV_TYPE. Choose a listed environment name or a number from 1 to 65."
        if [ "$BEING_SOURCED" = true ]; then
            return 1
        fi
    fi
    ENV_TYPE="$ENV_TYPE_MAPPED"
fi

# Set environment name based on type
ENV_NAME=$(resolve_env_name "$ENV_TYPE")

ENV_PATH="$HOME/${ENV_NAME}"

# Ask for HuggingFace model storage location
DEFAULT_HF_PATH="/workspace/models/huggingface"
if [ "$AUTO_MODE" = false ]; then
    echo ""
    print_info "Where would you like to store HuggingFace models?"
    print_info "Default: $DEFAULT_HF_PATH"
    read -r -p "Enter path (press Enter for default): " HF_PATH_INPUT
    
    if [ -z "$HF_PATH_INPUT" ]; then
        HF_PATH="$DEFAULT_HF_PATH"
        print_info "Using default path: $HF_PATH"
    else
        # Expand tilde if present
        HF_PATH="${HF_PATH_INPUT/#\~/$HOME}"
        print_info "Using custom path: $HF_PATH"
    fi
else
    HF_PATH="$DEFAULT_HF_PATH"
    print_info "Using default HuggingFace path: $HF_PATH"
fi

if ! select_cuda_for_env; then
    if [ "$BEING_SOURCED" = false ]; then
        exit 1
    else
        return 1
    fi
fi

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v python &> /dev/null; then
    print_error "Python is not available on PATH. Please ensure Python is installed and accessible before running this script."
    if [ "$BEING_SOURCED" = false ]; then
        exit 1
    else
        return 1
    fi
fi

PYTHON_BIN=$(command -v python)
PYTHON_VERSION=$($PYTHON_BIN --version 2>&1)
print_info "Using Python from: $PYTHON_BIN ($PYTHON_VERSION)"

if ! uses_pip_venv && ! command -v uv &> /dev/null; then
    print_error "uv is not installed. Please run 04_install_python.sh first."
    if [ "$BEING_SOURCED" = false ]; then
        exit 1
    else
        return 1
    fi
fi

# Check if environment exists and handle rebuild
if [ -d "$ENV_PATH" ]; then
    print_warning "⚠️  Environment $ENV_NAME already exists at $ENV_PATH"

    ENVIRONMENT_USABLE=true
    if ! environment_is_usable; then
        ENVIRONMENT_USABLE=false
        print_warning "Environment $ENV_NAME does not contain a working virtual-environment interpreter."
    fi

    if [ "$AUTO_MODE" = false ]; then
        echo ""
        print_info "Do you want to rebuild it? This will:"
        print_info "  • Delete the existing environment directory"
        print_info "  • Remove all installed packages"
        print_info "  • Create a fresh environment"
        echo ""

        while true; do
            read -r -p "Rebuild environment? (y/n): " RECREATE
            case ${RECREATE,,} in
                y|yes)
                    break
                    ;;
                n|no)
                    break
                    ;;
                *)
                    print_error "Please answer 'y' for yes or 'n' for no"
                    ;;
            esac
        done
    elif [ "$ENVIRONMENT_USABLE" = false ]; then
        RECREATE="y"
        print_warning "Auto mode: rebuilding the unusable environment."
    else
        RECREATE="n"
    fi

    if [[ "$RECREATE" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
        print_info "Destroying existing environment..."
        print_command "rm -rf $ENV_PATH"
        if ! rm -rf "$ENV_PATH"; then
            fail_script "Failed to remove unusable environment at $ENV_PATH"
            if [ "$BEING_SOURCED" = true ]; then
                return 1
            fi
        fi
        print_info "✓ Environment destroyed"
    elif [ "$ENVIRONMENT_USABLE" = false ]; then
        fail_script "Environment $ENV_NAME cannot be used without rebuilding it."
        if [ "$BEING_SOURCED" = true ]; then
            return 1
        fi
    elif [ "$AUTO_MODE" = true ]; then
        print_info "Using existing environment (use without --auto to be prompted)"
    else
        print_info "Keeping existing environment"
    fi
fi

if [ ! -d "$ENV_PATH" ]; then
    if uses_pip_venv; then
        print_info "Creating pip virtual environment at $ENV_PATH using $PYTHON_BIN..."
        VENV_CREATED=false
        if "$PYTHON_BIN" -m venv "$ENV_PATH"; then
            VENV_CREATED=true
        fi
    else
        print_info "Creating uv virtual environment at $ENV_PATH using $PYTHON_BIN..."
        UV_VENV_ARGS=()
        if [[ "${RECREATE:-n}" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
            UV_VENV_ARGS+=(--clear)
        fi
        VENV_CREATED=false
        if uv venv "${UV_VENV_ARGS[@]}" "$ENV_PATH" --python "$PYTHON_BIN"; then
            VENV_CREATED=true
        fi
    fi
    
    if [ "$VENV_CREATED" = true ]; then
        print_info "✓ Virtual environment created successfully"
    else
        print_error "Failed to create virtual environment"
        if [ "$BEING_SOURCED" = false ]; then
            exit 1
        else
            return 1
        fi
    fi
fi

write_cuda_env_config

# Install baseline Hugging Face Hub tooling into the selected environment.
if ! install_huggingface_hub; then
    fail_script "Failed to install Hugging Face Hub"
    if [ "$BEING_SOURCED" = true ]; then
        return 1
    fi
fi

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
             { [[ "$GPU_NAME" == *"RTX 5000"* ]] && [[ "$GPU_NAME" != *"ADA"* ]]; } || \
             { [[ "$GPU_NAME" == *"RTX 4000"* ]] && [[ "$GPU_NAME" != *"ADA"* ]]; } || \
             { [[ "$GPU_NAME" == *"RTX 6000"* ]] && [[ "$GPU_NAME" != *"ADA"* ]]; }; then
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
             { [[ "$GPU_NAME" == *"RTX 6000"* ]] && [[ "$GPU_NAME" == *"ADA"* ]]; } || \
             { [[ "$GPU_NAME" == *"RTX 5000"* ]] && [[ "$GPU_NAME" == *"ADA"* ]]; } || \
             { [[ "$GPU_NAME" == *"RTX 4000"* ]] && [[ "$GPU_NAME" == *"ADA"* ]]; }; then
            TORCH_CUDA_ARCH_LIST="8.9"
            print_info "  → $GPU_NAME (Ada Lovelace) detected: sm_89"
            
        elif [[ "$GPU_NAME" == *"H100"* ]] || [[ "$GPU_NAME" == *"H200"* ]] || [[ "$GPU_NAME" == *"GH200"* ]]; then
            TORCH_CUDA_ARCH_LIST="9.0"
            print_info "  → $GPU_NAME (Hopper) detected: sm_90"
            
        elif [[ "$GPU_NAME" == *"B200"* ]]; then
            TORCH_CUDA_ARCH_LIST="10.0"
            print_info "  → $GPU_NAME (Blackwell) detected: sm_100"
            
        elif [[ "$GPU_NAME" == *"RTX 5090"* ]] || [[ "$GPU_NAME" == *"5090"* ]] || \
             { [[ "$GPU_NAME" == *"RTX PRO 6000"* ]] && [[ "$GPU_NAME" == *"BLACKWELL"* ]]; }; then
            TORCH_CUDA_ARCH_LIST="12.0"
            print_info "  → $GPU_NAME (Blackwell) detected: sm_120"
            
        else
            print_warning "  → Unknown GPU model, will use default PyTorch CUDA architectures"
        fi
        
        if [ -n "$TORCH_CUDA_ARCH_LIST" ]; then
            print_info "  → Set TORCH_CUDA_ARCH_LIST=$TORCH_CUDA_ARCH_LIST"
        fi
    else
        print_warning "Could not detect GPU name"
    fi
else
    print_warning "nvidia-smi not found - no GPU detected"
fi

echo ""

# Create activation script with environment variables
print_info "Creating activation script with ML environment variables..."

CUDA_ACTIVATE_SNIPPET=$(cat <<'CUDA_ACTIVATE_SNIPPET'

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
        printf -v "$var_name" '%s' "$dir:$current"
    else
        printf -v "$var_name" '%s' "$dir"
    fi
    export "$var_name"
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
    local cuda_config="${VIRTUAL_ENV:-}/.cuda_env"
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
                echo "[ERROR] Selected CUDA toolkit is not available: $CUDA_ENV_HOME"
                echo "[ERROR] Install CUDA first with ./03_install_cuda.sh or rerun 05_setup_env.sh to select another CUDA version."
                return 1
            fi
            export CUDA_HOME="${CUDA_ENV_HOME%/}"
            export CUDA_PATH="$CUDA_HOME"
            export ML_ENV_CUDA_SOURCE="environment selection"
            ;;
        bashrc|"")
            local default_cuda_home
            if ! default_cuda_home=$(detect_default_cuda_home); then
                echo "[ERROR] No CUDA toolkit detected. Install CUDA first with ./03_install_cuda.sh."
                return 1
            fi
            export CUDA_HOME="${default_cuda_home%/}"
            export CUDA_PATH="$CUDA_HOME"
            export CUDA_ENV_MODE="bashrc"
            export ML_ENV_CUDA_SOURCE="bashrc default"
            ;;
        *)
            echo "[ERROR] Invalid CUDA_ENV_MODE in $cuda_config: $CUDA_ENV_MODE"
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
}

apply_env_cuda_selection || return 1 2>/dev/null || exit 1
CUDA_ACTIVATE_SNIPPET
)

cat > "$ENV_PATH/activate_ml" << EOF
#!/bin/bash
# Activate virtual environment
source "$ENV_PATH/bin/activate"
export DG_JIT_CACHE_DIR="\${VIRTUAL_ENV:-$ENV_PATH}/.cache/deep_gemm"
export FLASHINFER_WORKSPACE_BASE="\${VIRTUAL_ENV:-$ENV_PATH}"
export SGLANG_DG_CACHE_DIR="\${VIRTUAL_ENV:-$ENV_PATH}/.cache/deep_gemm"
export TORCH_EXTENSIONS_DIR="\${VIRTUAL_ENV:-$ENV_PATH}/.cache/torch_extensions"
export TORCH_HOME="\${VIRTUAL_ENV:-$ENV_PATH}/.cache/torch"
export TORCHINDUCTOR_CACHE_DIR="\${VIRTUAL_ENV:-$ENV_PATH}/.cache/torchinductor"
export TRITON_CACHE_DIR="\${VIRTUAL_ENV:-$ENV_PATH}/.cache/triton"
export TRITON_HOME="\${VIRTUAL_ENV:-$ENV_PATH}"
export TVM_FFI_CACHE_DIR="\${VIRTUAL_ENV:-$ENV_PATH}/.cache/tvm-ffi"
export VLLM_CACHE_ROOT="\${VIRTUAL_ENV:-$ENV_PATH}/.cache/vllm"
export XDG_CACHE_HOME="\${VIRTUAL_ENV:-$ENV_PATH}/.cache"

# Set ML environment variables
export HF_HOME="$HF_PATH"
export HF_HUB_CACHE="$HF_PATH/hub"
${CUDA_ACTIVATE_SNIPPET}

# GPU architecture for PyTorch
${TORCH_CUDA_ARCH_LIST:+export TORCH_CUDA_ARCH_LIST="$TORCH_CUDA_ARCH_LIST"}

echo "ML environment activated with:"
echo "  - Virtual env: $ENV_PATH"
echo "  - HF_HOME: $HF_PATH"
echo "  - HF_HUB_CACHE: $HF_PATH/hub"
if [ -n "\${ML_ENV_CUDA_HOME:-}" ]; then
    echo "  - CUDA toolkit: \${ML_ENV_CUDA_HOME} (\${ML_ENV_CUDA_VERSION:-unknown}, \${ML_ENV_CUDA_SOURCE:-configured})"
fi
${TORCH_CUDA_ARCH_LIST:+echo "  - TORCH_CUDA_ARCH_LIST: $TORCH_CUDA_ARCH_LIST"}
echo "  - Python: \$(python --version)"
EOF

chmod +x "$ENV_PATH/activate_ml"

# Add environment variables to .bashrc if not present
print_info "Updating ~/.bashrc with environment variables..."

if ! grep -q "HF_HOME=" ~/.bashrc; then
    cat >> ~/.bashrc << EOF

# ML Environment Variables
export HF_HOME="$HF_PATH"
export HF_HUB_CACHE="$HF_PATH/hub"
${TORCH_CUDA_ARCH_LIST:+export TORCH_CUDA_ARCH_LIST="$TORCH_CUDA_ARCH_LIST"}
EOF
    print_info "Added HF_HOME to ~/.bashrc"
    if [ -n "$TORCH_CUDA_ARCH_LIST" ]; then
        print_info "Added TORCH_CUDA_ARCH_LIST to ~/.bashrc"
    fi
fi


# Create directory structure
print_info "Creating directory structure..."
# Get parent directories from HF_PATH
HF_PARENT=$(dirname "$HF_PATH")
HF_GRANDPARENT=$(dirname "$HF_PARENT")

DIRS=(
    "$HF_GRANDPARENT"
    "$HF_PARENT"
    "$HF_PATH"
    "$HF_PATH/hub"
    "/workspace/scripts"
    "/workspace/logs"
)

for dir in "${DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" 2>/dev/null || {
            print_warning "Could not create $dir - you may need to create it manually"
        }
    else
        print_info "✓ $dir exists"
    fi
done

echo ""
print_info "✅ ML environment setup complete!"
echo ""

# ACTIVATE IF BEING SOURCED
if [ "$BEING_SOURCED" = true ]; then
    print_info "Activating ML environment..."
    # shellcheck source=/dev/null
    if ! source "$ENV_PATH/activate_ml"; then
        fail_script "Failed to activate ML environment"
        return 1
    fi
else
    # Show activation instructions when run as script
    print_info "To activate the environment:"
    echo ""
    print_command "source $ENV_PATH/activate_ml"
    echo ""
    print_info "Or use the alias (after reloading shell):"
    print_command "source ~/.bashrc"
    print_command "$ENV_NAME"
    echo ""
    print_info "Or source this script to create and activate:"
    print_command "source $0"
fi
