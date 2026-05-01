#!/usr/bin/env bash
set -euo pipefail

exec env CUDA_VISIBLE_DEVICES=0,1,2,3 \
  SGLANG_CPU_OMP_THREADS_BIND='0-29|30-59|60-89|90-119|120-149|150-179|180-209|210-239' \
  SGLANG_DISABLE_DEEP_GEMM=1 \
  numactl --cpunodebind=0 --membind=0 \
  python -m sglang.launch_server \
    --host 0.0.0.0 \
    --port 8000 \
    --api-key YOUR_API_KEY \
    --model-path /workspace/models/huggingface/models--Qwen--Qwen3.5-397B-A17B-FP8/snapshots/ea5b4f81096f3901c91dea97f81324302495781d \
    --kt-weight-path /workspace/models/huggingface/models--Qwen--Qwen3.5-397B-A17B-FP8/snapshots/ea5b4f81096f3901c91dea97f81324302495781d \
    --kt-cpuinfer 32 \
    --kt-threadpool-count 1 \
    --kt-num-gpu-experts 456 \
    --kt-method FP8 \
    --kt-max-deferred-experts-per-token 2 \
    --kt-expert-placement-strategy uniform \
    --attention-backend triton \
    --trust-remote-code \
    --mem-fraction-static 0.90 \
    --fp8-gemm-backend triton \
    --moe-runner-backend triton \
    --chunked-prefill-size 4096 \
    --served-model-name qwen3 \
    --enable-mixed-chunk \
    --tensor-parallel-size 4 \
    --numa-node 0 0 0 0 0 0 0 0 \
    --enable-p2p-check \
    --disable-shared-experts-fusion \
    --disable-radix-cache
