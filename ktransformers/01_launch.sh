#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools/launch_config.sh
source "$script_dir/tools/launch_config.sh"
load_launch_config "$@"
setup_sglang_launch_log "$script_dir" "$(basename "$0" .sh)"

cmd=(
  env CUDA_VISIBLE_DEVICES="$CUDA_VISIBLE_DEVICES"
  "${ADDITIONAL_SGLANG_ENV_ARGS[@]}"
  numactl --cpunodebind="$NUMACTL_CPUNODEBIND" --membind="$NUMACTL_MEMBIND"
  python -m sglang.launch_server \
    --host 0.0.0.0 \
    --port 8000 \
    --api-key YOUR_API_KEY \
    --model-path "$model_path" \
    --kt-weight-path "$model_path" \
    --kt-cpuinfer "$KT_CPUINFER" \
    --kt-threadpool-count "$KT_THREADPOOL_COUNT" \
    --kt-num-gpu-experts "$KT_NUM_GPU_EXPERTS" \
    --kt-method "$KT_METHOD" \
    --kt-max-deferred-experts-per-token "$KT_MAX_DEFERRED_EXPERTS_PER_TOKEN" \
    --kt-expert-placement-strategy uniform \
    --trust-remote-code \
    --context-length "$CONTEXT_LENGTH" \
    --max-total-tokens "$MAX_TOTAL_TOKENS" \
    --mem-fraction-static "$MEM_FRACTION_STATIC" \
    --chunked-prefill-size "$CHUNKED_PREFILL_SIZE" \
    --served-model-name "$SERVED_MODEL_NAME" \
    --enable-mixed-chunk \
    --tensor-parallel-size "$TENSOR_PARALLEL_SIZE" \
    --numa-node "${NUMA_NODE_ARGS[@]}" \
    --enable-p2p-check \
    --disable-shared-experts-fusion \
    --disable-radix-cache \
    --disable-chunked-prefix-cache \
    --enable-metrics \
    --collect-tokens-histogram \
    "${ADDITIONAL_SGLANG_ARG_LIST[@]}"
)
print_launch_command "${cmd[@]}"
exec "${cmd[@]}"
