#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
recorder_dir="$script_dir/01"
output_recorder_dir="$script_dir/02"
: "${HF_HOME:?HF_HOME must be set to the Hugging Face model cache path}"
HF_HUB_CACHE="${HF_HUB_CACHE:-$HF_HOME/hub}"
model_path="$HF_HUB_CACHE/models--Qwen--Qwen3.5-122B-A10B-FP8/snapshots/a099dee70ccfcd8d5dda56aaa0b60cb8ecadabc9"

if [[ ! -d "$recorder_dir" ]]; then
  echo "Recorder directory not found: $recorder_dir" >&2
  exit 1
fi

latest_expert_location="$(find "$recorder_dir" -maxdepth 1 -type f -name 'expert_distribution_recorder_*.pt' | sort -V | tail -n 1)"

if [[ -z "$latest_expert_location" ]]; then
  echo "No expert_distribution_recorder_*.pt files found in $recorder_dir" >&2
  exit 1
fi

exec env CUDA_VISIBLE_DEVICES=0 \
  SGLANG_EXPERT_DISTRIBUTION_RECORDER_DIR="$output_recorder_dir" \
  SGLANG_CPU_OMP_THREADS_BIND='16-31,48-63' \
  numactl --cpunodebind=1 --membind=1 \
  python -m sglang.launch_server \
    --host 0.0.0.0 \
    --port 8000 \
    --api-key YOUR_API_KEY \
    --model-path "$model_path" \
    --kt-weight-path "$model_path" \
    --kt-cpuinfer 16 \
    --kt-threadpool-count 1 \
    --kt-num-gpu-experts 176 \
    --kt-method FP8 \
    --kt-max-deferred-experts-per-token 2 \
    --kt-expert-placement-strategy frequency \
    --init-expert-location "$latest_expert_location" \
    --record-kt-gpu-expert-distribution \
    --expert-distribution-recorder-mode stat \
    --expert-distribution-recorder-buffer-size -1 \
    --trust-remote-code \
    --mem-fraction-static 0.90 \
    --chunked-prefill-size 4096 \
    --served-model-name qwen3 \
    --enable-mixed-chunk \
    --tensor-parallel-size 1 \
    --numa-node 1 1 1 1 1 1 1 1 \
    --enable-p2p-check \
    --disable-shared-experts-fusion \
    --disable-radix-cache
