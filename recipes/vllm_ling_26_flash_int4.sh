#!/usr/bin/env bash

# Mandatory inference configuration
INFERENCE_PROVIDER="vLLM"
INFERENCE_ENV=""
MODEL_REPO="inclusionAI/Ling-2.6-flash-int4"
MODEL_NAME="ling"
SERVED_MODEL_NAME="ling"
CONTEXT_LEN_VALUE=131072
DEFAULT_TENSOR_PARALLEL_SIZE=2
TRUST_REMOTE_CODE="--trust-remote-code"
REASONING_PARSER=""
ENABLE_AUTO_TOOL_CHOICE="--enable-auto-tool-choice"
TOOL_CALL_PARSER="--tool-call-parser hermes"
GPU_MEM_UTIL_VALUE=0.95
METRICS_FLAG=""
HOST="0.0.0.0"
DEFAULT_PORT=8000
API_KEY="--api-key YOUR_API_KEY"

BACKEND_MOE_RUNNER_SM90=""
BACKEND_MOE_RUNNER_SM100=""
BACKEND_MOE_RUNNER_SM103=""
BACKEND_MOE_RUNNER_SM120=""
BACKEND_MOE_RUNNER_SM121=""

ENABLE_CACHE_FLAG=0
ENABLE_SPECULATIVE=0
ENABLE_REASONING_PARSER=0
SPECULATIVE=''
QUANTIZATION=""
NO_PREFIX_CACHE="--no-enable-prefix-caching"
SCRIPT_DIR=""
REASONING_PARSER_PLUGIN="${SCRIPT_DIR:+$SCRIPT_DIR/plugins/super_v3_reasoning_parser.py}"
EXTRA_ARGS=""

case "${INFERENCE_PROVIDER,,}" in
    sglang)
        INFERENCE_LAUNCH="sglang serve"
        MODEL_PATH="--model-path $MODEL_REPO"
        TENSOR_PARALLEL_SIZE_FLAG="--tp"
        CONTEXT_LEN_FLAG="--context-length $CONTEXT_LEN_VALUE"
        GPU_MEM_UTIL_FLAG="--mem-fraction-static $GPU_MEM_UTIL_VALUE"
        ;;
    vllm)
        INFERENCE_LAUNCH="vllm serve"
        MODEL_PATH="$MODEL_REPO"
        TENSOR_PARALLEL_SIZE_FLAG="--tensor-parallel-size"
        CONTEXT_LEN_FLAG="--max-model-len $CONTEXT_LEN_VALUE"
        GPU_MEM_UTIL_FLAG="--gpu-memory-utilization $GPU_MEM_UTIL_VALUE"
        ;;
    *)
        echo "INFERENCE_LAUNCH needs a value" >&2
        exit 1
        ;;
esac

# Runtime argument state
DEFAULT_ENABLE_SPECULATIVE="$ENABLE_SPECULATIVE"
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
    local sm_version=""

    if [ -n "$BACKEND_MOE_RUNNER_SM90" ] ||
        [ -n "$BACKEND_MOE_RUNNER_SM100" ] ||
        [ -n "$BACKEND_MOE_RUNNER_SM103" ] ||
        [ -n "$BACKEND_MOE_RUNNER_SM120" ] ||
        [ -n "$BACKEND_MOE_RUNNER_SM121" ]; then
        sm_version="$(get_cuda_sm_version || true)"
    fi

    case "$sm_version" in
        sm_90)
            BACKEND_MOE_RUNNER="$BACKEND_MOE_RUNNER_SM90"
            ;;
        sm_100)
            BACKEND_MOE_RUNNER="$BACKEND_MOE_RUNNER_SM100"
            ;;
        sm_103)
            BACKEND_MOE_RUNNER="$BACKEND_MOE_RUNNER_SM103"
            ;;
        sm_120)
            BACKEND_MOE_RUNNER="$BACKEND_MOE_RUNNER_SM120"
            ;;
        sm_121)
            BACKEND_MOE_RUNNER="$BACKEND_MOE_RUNNER_SM121"
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
    ENABLE_SPECULATIVE="$DEFAULT_ENABLE_SPECULATIVE"
    ENABLE_CACHE_FLAG=0
    POSITIONAL_ARGS=()

    local arg
    for arg in "$@"; do
        case "$arg" in
            --speculative)
                ENABLE_SPECULATIVE=1
                ;;
            --cache)
                ENABLE_CACHE_FLAG=1
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
    TENSOR_PARALLEL_SIZE_VALUE="$(count_gpus "$gpu_list")"
}

build_extra_args() {
    local configured_extra_args="$EXTRA_ARGS"
    EXTRA_ARGS=""
    if [ -n "$configured_extra_args" ]; then
        EXTRA_ARGS+="$configured_extra_args "
    fi
    configure_moe_runner_backend

    if [ "$ENABLE_SPECULATIVE" -eq 1 ]; then
        EXTRA_ARGS+="$SPECULATIVE "
    fi
    EXTRA_ARGS+="$QUANTIZATION "
    if [ "$ENABLE_CACHE_FLAG" -eq 1 ]; then
        EXTRA_ARGS+="$NO_PREFIX_CACHE "
    fi
    if [ -n "$BACKEND_MOE_RUNNER" ]; then
        EXTRA_ARGS+="--moe-runner-backend ${BACKEND_MOE_RUNNER} "
    fi
}

get_speculative_value() {
    local target="$1"
    local previous=""
    local token

    for token in $SPECULATIVE; do
        if [ "$previous" = "$target" ]; then
            printf '%s' "$token"
            return
        fi
        previous="$token"
    done
}

print_speculative_config() {
    if [ "$ENABLE_SPECULATIVE" -ne 1 ] || [ -z "$SPECULATIVE" ]; then
        return
    fi

    if [ "$INFERENCE_PROVIDER" = "SGLang" ]; then
        echo "Speculative Algo: $(get_speculative_value --speculative-algo)"
        echo "Speculative Number of Steps: $(get_speculative_value --speculative-num-steps)"
        echo "Speculative Eagle TopK: $(get_speculative_value --speculative-eagle-topk)"
        echo "Speculative Number of Draft Tokens: $(get_speculative_value --speculative-num-draft-tokens)"
    else
        echo "Speculative Config: $SPECULATIVE"
    fi
}

get_tensor_parallel_size() {
    local arg_value="$1"
    GPU_SELECTION_MODE="tensor"

    if [ -n "$arg_value" ]; then
        if is_valid_tensor_parallel_size "$arg_value"; then
            TENSOR_PARALLEL_SIZE_VALUE="$arg_value"
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
            TENSOR_PARALLEL_SIZE_VALUE="$DEFAULT_TENSOR_PARALLEL_SIZE"
            break
        elif is_valid_tensor_parallel_size "$size"; then
            TENSOR_PARALLEL_SIZE_VALUE="$size"
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
    echo "Model name: $MODEL_NAME"
    echo "Served as: $SERVED_MODEL_NAME"
    echo "Tensor parallel size: $TENSOR_PARALLEL_SIZE_VALUE"
    if [ "$GPU_SELECTION_MODE" = "custom" ]; then
        echo "GPU selection: CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES_VALUE"
    fi
    echo "Port: $INFERENCE_PORT"
    print_speculative_config
    if [ -n "$BACKEND_MOE_RUNNER" ]; then
        echo "MoE runner backend: $BACKEND_MOE_RUNNER"
    fi
    echo ""

    if [ "$ENABLE_REASONING_PARSER" -eq 1 ] && [ ! -f "$REASONING_PARSER_PLUGIN" ]; then
        echo "Missing reasoning parser plugin: $REASONING_PARSER_PLUGIN"
        exit 1
    fi

    local base_command="$INFERENCE_ENV"
    base_command+=" $INFERENCE_LAUNCH"
    base_command+=" $MODEL_PATH"
    base_command+=" --served-model-name $SERVED_MODEL_NAME"
    base_command+=" $TRUST_REMOTE_CODE"
    base_command+=" $TENSOR_PARALLEL_SIZE_FLAG $TENSOR_PARALLEL_SIZE_VALUE"
    base_command+=" $REASONING_PARSER"
    base_command+=" $ENABLE_AUTO_TOOL_CHOICE"
    base_command+=" $TOOL_CALL_PARSER"
    base_command+=" $CONTEXT_LEN_FLAG"
    base_command+=" $GPU_MEM_UTIL_FLAG"
    base_command+=" $METRICS_FLAG"
    base_command+=" --host $HOST"
    base_command+=" --port $INFERENCE_PORT"
    base_command+=" $API_KEY"
    base_command+=" ${EXTRA_ARGS}"

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
