#!/usr/bin/env bash

INFERENCE_PROVIDER="SGLang"
MODEL_REPO="deepseek-ai/DeepSeek-V4-Flash"
MODEL_NAME="deepseek_v4"
MAX_MODEL_LEN=1048576
DEFAULT_TENSOR_PARALLEL_SIZE=2
DEFAULT_PORT=8000
GPU_MEM_UTIL=0.90

SPECULATIVE='--speculative-algo EAGLE --speculative-num-steps 3 --speculative-eagle-topk 1 --speculative-num-draft-tokens 4'
QUANTIZATION=""
NO_PREFIX_CACHE="--disable-radix-cache --disable-chunked-prefix-cache"
EXTRA_ARGS=""
ENABLE_SPECULATIVE=0
POSITIONAL_ARGS=()

RECIPE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LOG_SUFFIX="${INFERENCE_PROVIDER,,}"
case "$LOG_SUFFIX" in
    vllm|sglang)
        ;;
    *)
        echo "Error: unsupported inference provider for logging: $INFERENCE_PROVIDER" >&2
        exit 1
        ;;
esac
LOG_DIR="$RECIPE_DIR/logs"
LOG_TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LAUNCH_LOG="$LOG_DIR/${LOG_TIMESTAMP}_${LOG_SUFFIX}.log"
LAUNCH_LOG_REL="./logs/${LOG_TIMESTAMP}_${LOG_SUFFIX}.log"
if ! mkdir -p "$LOG_DIR"; then
    echo "Error: unable to create log directory: $LOG_DIR" >&2
    exit 1
fi
if ! : > "$LAUNCH_LOG"; then
    echo "Error: unable to write log file: $LAUNCH_LOG" >&2
    exit 1
fi
if [ "$LOG_SUFFIX" = "sglang" ]; then
    SGLANG_LAUNCH_LOG="$LAUNCH_LOG"
    export SGLANG_LAUNCH_LOG
else
    VLLM_LAUNCH_LOG="$LAUNCH_LOG"
    export VLLM_LAUNCH_LOG
fi
exec > >(tee -a "$LAUNCH_LOG") 2>&1
echo "$INFERENCE_PROVIDER log: $LAUNCH_LOG_REL"
echo "Full log path: $LAUNCH_LOG"

echo ""
echo "$MODEL_REPO $INFERENCE_PROVIDER Launcher"

trap 'echo -e "\n\nServer stopped by user."; exit 0' INT

get_cuda_sm_version() {
    local visible_devices="${CUDA_VISIBLE_DEVICES:-}"

    if [ "${GPU_SELECTION_MODE:-}" = "custom" ]; then
        visible_devices="$CUDA_VISIBLE_DEVICES_VALUE"
    fi

    if [ -n "$visible_devices" ]; then
        CUDA_VISIBLE_DEVICES="$visible_devices" python3 - <<'PY' 2>/dev/null
import torch

if torch.cuda.is_available():
    major, minor = torch.cuda.get_device_capability(0)
    print(f"sm_{major}{minor}")
PY
    else
        python3 - <<'PY' 2>/dev/null
import torch

if torch.cuda.is_available():
    major, minor = torch.cuda.get_device_capability(0)
    print(f"sm_{major}{minor}")
PY
    fi
}

configure_moe_runner_backend() {
    local sm_version
    sm_version="$(get_cuda_sm_version || true)"

    case "$sm_version" in
        sm_90)
            BACKEND_MOE_RUNNER="flashinfer_mxfp4"
            ;;
        sm_100|sm_103)
            BACKEND_MOE_RUNNER="flashinfer_mxfp4"
            ;;
        *)
            BACKEND_MOE_RUNNER="${BACKEND_MOE_RUNNER:-}"
            ;;
    esac

    export BACKEND_MOE_RUNNER
}

is_valid_tensor_parallel_size() {
    [[ "$1" =~ ^(1|2|4|8)$ ]]
}

is_valid_gpu_list() {
    [[ "$1" =~ ^[0-9]+(,[0-9]+)*$ ]]
}

count_gpus() {
    local list="$1"
    local IFS=,
    local gpu_array=()
    read -ra gpu_array <<< "$list"
    echo "${#gpu_array[@]}"
}

is_valid_port() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

parse_arguments() {
    ENABLE_SPECULATIVE=0
    POSITIONAL_ARGS=()

    local arg
    for arg in "$@"; do
        case "$arg" in
            --speculative)
                ENABLE_SPECULATIVE=1
                ;;
            *)
                POSITIONAL_ARGS+=("$arg")
                ;;
        esac
    done
}

set_custom_gpus() {
    local gpu_list="$1"
    GPU_SELECTION_MODE="custom"
    CUDA_VISIBLE_DEVICES_VALUE="$gpu_list"
    TENSOR_PARALLEL_SIZE="$(count_gpus "$gpu_list")"
}

build_extra_args() {
    EXTRA_ARGS=""
    configure_moe_runner_backend

    if [ "$ENABLE_SPECULATIVE" -eq 1 ]; then
        EXTRA_ARGS+="$SPECULATIVE "
    fi
    EXTRA_ARGS+="$QUANTIZATION "
    EXTRA_ARGS+="$NO_PREFIX_CACHE "
    if [ -n "$BACKEND_MOE_RUNNER" ]; then
        EXTRA_ARGS+="--moe-runner-backend ${BACKEND_MOE_RUNNER} "
    fi
}

get_tensor_parallel_size() {
    local arg_value="$1"
    GPU_SELECTION_MODE="tensor"

    if [ -n "$arg_value" ]; then
        if is_valid_tensor_parallel_size "$arg_value"; then
            TENSOR_PARALLEL_SIZE="$arg_value"
            return
        elif [[ "$arg_value" =~ ^gpus?=(.*)$ ]]; then
            local gpu_list="${BASH_REMATCH[1]}"
            if is_valid_gpu_list "$gpu_list"; then
                set_custom_gpus "$gpu_list"
                return
            else
                echo "Invalid GPU list in argument '$arg_value'. Expected format gpus=0,1,2."
                exit 1
            fi
        elif [[ "$arg_value" == *","* ]] && is_valid_gpu_list "$arg_value"; then
            set_custom_gpus "$arg_value"
            return
        else
            echo "Invalid tensor parallel argument '$arg_value'. Use 1/2/4/8 or gpus=0,1."
            exit 1
        fi
    fi

    GPU_SELECTION_MODE="tensor"
    while true; do
        echo ""
        echo "============================================================"
        echo "Tensor Parallel Configuration"
        echo "============================================================"
        echo ""
        echo "Tensor parallel size determines how many GPUs to use:"
        echo "  1 = Single GPU"
        echo "  2 = 2 GPUs"
        echo "  4 = 4 GPUs"
        echo "  8 = 8 GPUs (default)"
        echo ""
        echo "Or type 'custom' (or provide a comma-separated list like 0,2,3) to set specific GPU IDs (overrides tensor parallel size)."
        echo ""

        read -r -p "Enter tensor parallel size (1/2/4/8) or 'custom' [default: ${DEFAULT_TENSOR_PARALLEL_SIZE}]: " size
        size="${size,,}"

        if [ -z "$size" ]; then
            TENSOR_PARALLEL_SIZE="$DEFAULT_TENSOR_PARALLEL_SIZE"
            break
        elif is_valid_tensor_parallel_size "$size"; then
            TENSOR_PARALLEL_SIZE="$size"
            break
        elif [[ "$size" == "custom" || "$size" == "c" ]]; then
            read -r -p "Enter GPU IDs to use (comma-separated, e.g., 0,2,3): " custom_list
            if is_valid_gpu_list "$custom_list"; then
                set_custom_gpus "$custom_list"
                break
            else
                echo "Invalid GPU list. Expected comma-separated integers (e.g., 0,1,3)."
            fi
        elif [[ "$size" == *","* ]] && is_valid_gpu_list "$size"; then
            set_custom_gpus "$size"
            break
        else
            echo "Invalid choice. Please enter 1, 2, 4, 8, or a comma-separated GPU list."
        fi
    done
}

get_port() {
    local arg_value="$1"

    if [ -n "$arg_value" ]; then
        if is_valid_port "$arg_value"; then
            INFERENCE_PORT="$arg_value"
            return
        else
            echo "Invalid port '$arg_value'. Please provide a value between 1 and 65535."
            exit 1
        fi
    fi

    while true; do
        echo ""
        echo "============================================================"
        echo "$INFERENCE_PROVIDER Server Port"
        echo "============================================================"
        echo ""

        read -r -p "Enter Inference Provider server port [default: ${DEFAULT_PORT}]: " port

        if [ -z "$port" ]; then
            INFERENCE_PORT="$DEFAULT_PORT"
            break
        elif is_valid_port "$port"; then
            INFERENCE_PORT="$port"
            break
        else
            echo "Invalid port. Please enter a number between 1 and 65535."
        fi
    done
}

main() {
    parse_arguments "$@"
    get_tensor_parallel_size "${POSITIONAL_ARGS[0]}"
    get_port "${POSITIONAL_ARGS[1]}"
    build_extra_args

    echo ""
    echo "============================================================"
    echo "Starting $INFERENCE_PROVIDER Server"
    echo "============================================================"
    echo "Model: $MODEL_REPO"
    echo "Served as: $MODEL_NAME"
    echo "Tensor parallel size: $TENSOR_PARALLEL_SIZE"
    if [ "$GPU_SELECTION_MODE" = "custom" ]; then
        echo "GPU selection: CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES_VALUE"
    fi
    echo "Port: $INFERENCE_PORT"
    if [ -n "$BACKEND_MOE_RUNNER" ]; then
        echo "MoE runner backend: $BACKEND_MOE_RUNNER"
    fi
    echo ""

    local base_command+=" sglang serve"
    base_command+=" --model-path $MODEL_REPO"
    base_command+=" --served-model-name $MODEL_NAME"
    base_command+=" --trust-remote-code"
    base_command+=" --tp $TENSOR_PARALLEL_SIZE"
    base_command+=" --reasoning-parser deepseek-v4"
    base_command+=" --tool-call-parser deepseekv4"
    base_command+=" --context-length $MAX_MODEL_LEN"
    base_command+=" --mem-fraction-static ${GPU_MEM_UTIL}"
    base_command+=" --enable-metrics"
    base_command+=" --collect-tokens-histogram"
    base_command+=" ${EXTRA_ARGS}--host 0.0.0.0"
    base_command+=" --port $INFERENCE_PORT"
    base_command+=" --api-key YOUR_API_KEY"

    if [ "$GPU_SELECTION_MODE" = "custom" ]; then
        echo "Command: CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES_VALUE $base_command"
    else
        echo "Command: $base_command"
    fi
    echo ""
    echo "Press Ctrl+C to stop the server"
    echo "============================================================"
    echo ""

    if [ "$GPU_SELECTION_MODE" = "custom" ]; then
        CUDA_VISIBLE_DEVICES="$CUDA_VISIBLE_DEVICES_VALUE" \
            $base_command
    else
        $base_command
    fi
}

main "$@"
