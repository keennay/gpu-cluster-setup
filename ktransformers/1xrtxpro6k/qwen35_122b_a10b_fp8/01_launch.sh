#!/usr/bin/env bash
set -euo pipefail

: "${HF_HOME:?HF_HOME must be set to the Hugging Face model cache path}"
HF_HUB_CACHE="${HF_HUB_CACHE:-$HF_HOME/hub}"
model_path="$HF_HUB_CACHE/models--Qwen--Qwen3.5-122B-A10B-FP8/snapshots/a099dee70ccfcd8d5dda56aaa0b60cb8ecadabc9"

exec env CUDA_VISIBLE_DEVICES=0 \
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
    --kt-expert-placement-strategy uniform \
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
