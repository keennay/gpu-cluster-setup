#!/usr/bin/env bash
set -euo pipefail

exec env CUDA_VISIBLE_DEVICES=0 \
  SGLANG_EXPERT_DISTRIBUTION_RECORDER_DIR=/workspace/sessions/1xrtxpro6k/qwen35_122b_a10b_fp8 \
  SGLANG_CPU_OMP_THREADS_BIND='0-29|30-59|60-89|90-119|120-149|150-179|180-209|210-239' \
  SGLANG_DISABLE_DEEP_GEMM=1 \
  numactl --cpunodebind=0 --membind=0 \
  python -m sglang.launch_server \
    --host 0.0.0.0 \
    --port 8000 \
    --api-key YOUR_API_KEY \
    --model-path /workspace/models/huggingface/models--Qwen--Qwen3.5-122B-A10B-FP8/snapshots/a099dee70ccfcd8d5dda56aaa0b60cb8ecadabc9 \
    --kt-weight-path /workspace/models/huggingface/models--Qwen--Qwen3.5-122B-A10B-FP8/snapshots/a099dee70ccfcd8d5dda56aaa0b60cb8ecadabc9 \
    --kt-cpuinfer 32 \
    --kt-threadpool-count 1 \
    --kt-num-gpu-experts 184 \
    --kt-method FP8 \
    --kt-max-deferred-experts-per-token 2 \
    --kt-expert-placement-strategy frequency \
    --init-expert-location /workspace/scripts/ktransformers/1xrtxpro6k/qwen35_122b_a10b_fp8/expert_distribution_recorder_1777651830.5108323.pt \
    --record-kt-gpu-expert-distribution \
    --expert-distribution-recorder-mode stat \
    --expert-distribution-recorder-buffer-size -1 \
    --attention-backend triton \
    --trust-remote-code \
    --mem-fraction-static 0.95 \
    --fp8-gemm-backend triton \
    --moe-runner-backend triton \
    --chunked-prefill-size 4096 \
    --served-model-name qwen3 \
    --enable-mixed-chunk \
    --tensor-parallel-size 1 \
    --numa-node 0 0 0 0 0 0 0 0 \
    --enable-p2p-check \
    --disable-shared-experts-fusion \
    --disable-radix-cache
