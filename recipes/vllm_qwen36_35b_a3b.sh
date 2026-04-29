#!/usr/bin/env bash

INFERENCE_PROVIDER="vLLM"
MODEL_REPO="Qwen/Qwen3.6-35B-A3B"
MODEL_NAME="qwen3"
DEFAULT_TENSOR_PARALLEL_SIZE=1
DEFAULT_PORT=8000
GPU_MEM_UTIL=0.95

SPECULATIVE='--speculative-config {"method":"qwen3_next_mtp","num_speculative_tokens":2}'
QUANTIZATION=""
NO_PREFIX_CACHE="--no-enable-prefix-caching"
EXTRA_ARGS=""
ENABLE_SPECULATIVE=0
POSITIONAL_ARGS=()

echo ""
echo "$MODEL_REPO $INFERENCE_PROVIDER Launcher"

trap 'echo -e "\n\nServer stopped by user."; exit 0' INT

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

    if [ "$ENABLE_SPECULATIVE" -eq 1 ]; then
        EXTRA_ARGS+="$SPECULATIVE "
    fi
    EXTRA_ARGS+="$QUANTIZATION "
    EXTRA_ARGS+="$NO_PREFIX_CACHE "
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
    echo ""

    local base_command="vllm serve $MODEL_REPO"
    base_command+=" --served-model-name $MODEL_NAME"
    base_command+=" --trust-remote-code"
    base_command+=" --tensor-parallel-size $TENSOR_PARALLEL_SIZE"
    base_command+=" --reasoning-parser $MODEL_NAME"
    base_command+=" --enable-auto-tool-choice"
    base_command+=" --tool-call-parser qwen3_coder"
    base_command+=" --gpu-memory-utilization ${GPU_MEM_UTIL}"
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
