#!/usr/bin/env bash
set -euo pipefail

exec env CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 \
  SGLANG_CPU_OMP_THREADS_BIND='0-29|30-59|60-89|90-119|120-149|150-179|180-209|210-239' \
  numactl --cpunodebind=0 --membind=0 \
  python -m sglang.launch_server \
    --host 0.0.0.0 \
    --port 8000 \
    --api-key YOUR_API_KEY \
    --model-path /workspace/models/huggingface/models--Qwen--Qwen3.5-397B-A17B/snapshots/8472618112abcbd45acbcdc58436aff4233c23f7 \
    --kt-weight-path /workspace/models/huggingface/models--Qwen--Qwen3.5-397B-A17B/snapshots/8472618112abcbd45acbcdc58436aff4233c23f7 \
    --kt-cpuinfer 32 \
    --kt-threadpool-count 1 \
    --kt-num-gpu-experts 384 \
    --kt-method BF16 \
    --kt-max-deferred-experts-per-token 2 \
    --kt-expert-placement-strategy uniform \
    --attention-backend triton \
    --trust-remote-code \
    --mem-fraction-static 0.90 \
    --chunked-prefill-size 4096 \
    --served-model-name qwen3 \
    --enable-mixed-chunk \
    --tensor-parallel-size 8 \
    --numa-node 0 0 0 0 0 0 0 0 \
    --enable-p2p-check \
    --disable-shared-experts-fusion \
    --disable-radix-cache
