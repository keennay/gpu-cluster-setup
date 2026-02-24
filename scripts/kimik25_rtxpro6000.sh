#!/usr/bin/env bash
set -euo pipefail

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  IS_SOURCED=1
else
  IS_SOURCED=0
fi

# Kimi-K2.5 + SGLang (UV, CUDA 13) - Fast Startup Parity with Docker
# ===================================================================
#
# Goal
# - Match Docker startup behavior for Kimi-K2.5:
#   - "Loading safetensors checkpoint shards: 100%" -> server ready in under 5 minutes.
#   - On this host, validated UV runs are ~87-98 seconds for that segment (Docker baseline ~88 seconds).
#
# Primary root cause found
# - Slow UV runs inherited high CPU math thread env from shell:
#   - OMP_NUM_THREADS=32, MKL_NUM_THREADS=32, OPENBLAS_NUM_THREADS=32, NUMEXPR_NUM_THREADS=32, ...
# - With TP=8, this causes severe CPU oversubscription during hidden MoE weight materialization after shard 100%.
# - The shard progress bar is misleading: major loading work continues after 100%.
#
# Model path used below
# - /workspace/models/huggingface/models--moonshotai--Kimi-K2.5/snapshots/3367c8d1c68584429fab7faf845a32d5195b6ac1

VENV_PATH="${VENV_PATH:-${VIRTUAL_ENV:-/root/kimi-sglang_env}}"
CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"
MODEL_PATH="${MODEL_PATH:-/workspace/models/huggingface/models--moonshotai--Kimi-K2.5/snapshots/3367c8d1c68584429fab7faf845a32d5195b6ac1}"
SGLANG_COMMIT="${SGLANG_COMMIT:-c3d78ded2ebf0c38abdde0266a31a2a147a9b9cb}"
API_KEY="${API_KEY:-YOUR_API_KEY}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-kimi_k2}"
TP="${TP:-8}"
LOG="${LOG:-/tmp/sglang_uv_kimi_fast.log}"
ARCH="${ARCH:-$(uname -m)}"

detect_torch_cuda_arch_list() {
  local torch_arch=""

  if command -v nvidia-smi >/dev/null 2>&1; then
    local gpu_name
    gpu_name="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 | tr '[:lower:]' '[:upper:]')"

    if [ -n "${gpu_name}" ]; then
      if [[ "${gpu_name}" == *"V100"* ]]; then
        torch_arch="7.0"
      elif [[ "${gpu_name}" == *"T4"* ]] || \
           ([[ "${gpu_name}" == *"RTX 5000"* ]] && [[ "${gpu_name}" != *"ADA"* ]]) || \
           ([[ "${gpu_name}" == *"RTX 4000"* ]] && [[ "${gpu_name}" != *"ADA"* ]]) || \
           ([[ "${gpu_name}" == *"RTX 6000"* ]] && [[ "${gpu_name}" != *"ADA"* ]]); then
        torch_arch="7.5"
      elif [[ "${gpu_name}" == *"A100"* ]] || [[ "${gpu_name}" == *"A30"* ]]; then
        torch_arch="8.0"
      elif [[ "${gpu_name}" == *"RTX 3090"* ]] || [[ "${gpu_name}" == *"3090"* ]] || \
           [[ "${gpu_name}" == *"RTX 3080"* ]] || [[ "${gpu_name}" == *"3080"* ]] || \
           [[ "${gpu_name}" == *"RTX 3070"* ]] || [[ "${gpu_name}" == *"3070"* ]] || \
           [[ "${gpu_name}" == *"RTX A6000"* ]] || [[ "${gpu_name}" == *"A6000"* ]] || \
           [[ "${gpu_name}" == *"RTX A5000"* ]] || [[ "${gpu_name}" == *"A5000"* ]] || \
           [[ "${gpu_name}" == *"RTX A4500"* ]] || [[ "${gpu_name}" == *"A4500"* ]] || \
           [[ "${gpu_name}" == *"RTX A4000"* ]] || [[ "${gpu_name}" == *"A4000"* ]] || \
           [[ "${gpu_name}" == *"RTX A2000"* ]] || [[ "${gpu_name}" == *"A2000"* ]] || \
           [[ "${gpu_name}" == *"A10"* ]] || [[ "${gpu_name}" == *"A40"* ]]; then
        torch_arch="8.6"
      elif [[ "${gpu_name}" == *"RTX 4090"* ]] || [[ "${gpu_name}" == *"4090"* ]] || \
           [[ "${gpu_name}" == *"RTX 4070 TI"* ]] || [[ "${gpu_name}" == *"4070 TI"* ]] || \
           [[ "${gpu_name}" == *"L40S"* ]] || [[ "${gpu_name}" == *"L40"* ]] || [[ "${gpu_name}" == *"L4"* ]] || \
           ([[ "${gpu_name}" == *"RTX 6000"* ]] && [[ "${gpu_name}" == *"ADA"* ]]) || \
           ([[ "${gpu_name}" == *"RTX 5000"* ]] && [[ "${gpu_name}" == *"ADA"* ]]) || \
           ([[ "${gpu_name}" == *"RTX 4000"* ]] && [[ "${gpu_name}" == *"ADA"* ]]); then
        torch_arch="8.9"
      elif [[ "${gpu_name}" == *"H100"* ]] || [[ "${gpu_name}" == *"H200"* ]] || [[ "${gpu_name}" == *"GH200"* ]]; then
        torch_arch="9.0"
      elif [[ "${gpu_name}" == *"B200"* ]]; then
        torch_arch="10.0"
      elif [[ "${gpu_name}" == *"RTX 5090"* ]] || [[ "${gpu_name}" == *"5090"* ]] || \
           ([[ "${gpu_name}" == *"RTX PRO 6000"* ]] && [[ "${gpu_name}" == *"BLACKWELL"* ]]); then
        torch_arch="12.0"
      fi
    fi
  fi

  printf '%s' "${torch_arch}"
}

bootstrap_env_if_missing() {
  if [ -d "${VENV_PATH}" ]; then
    return 0
  fi

  echo "Environment not found at ${VENV_PATH}. Bootstrapping..."

  if ! command -v uv >/dev/null 2>&1; then
    echo "uv is required to create the environment but was not found in PATH."
    exit 1
  fi

  local default_hf_path="/workspace/models/huggingface"
  local hf_path_input=""
  local hf_path="${default_hf_path}"

  echo ""
  echo "Where would you like to store HuggingFace models?"
  echo "Default: ${default_hf_path}"
  read -r -p "Enter path (press Enter for default): " hf_path_input || true
  if [ -n "${hf_path_input}" ]; then
    hf_path="${hf_path_input/#\~/$HOME}"
  fi
  echo "Using HuggingFace path: ${hf_path}"

  local python_bin
  python_bin="$(command -v python)"
  if [ -z "${python_bin}" ]; then
    echo "python was not found in PATH."
    exit 1
  fi

  uv venv "${VENV_PATH}" --python "${python_bin}"

  local torch_arch
  torch_arch="$(detect_torch_cuda_arch_list)"
  if [ -n "${torch_arch}" ]; then
    echo "Detected TORCH_CUDA_ARCH_LIST=${torch_arch}"
  else
    echo "Could not determine TORCH_CUDA_ARCH_LIST automatically; leaving unset."
  fi

  cat > "${VENV_PATH}/activate_ml" <<EOF
#!/usr/bin/env bash
source "${VENV_PATH}/bin/activate"
export HF_HOME="${hf_path}"
export HUGGINGFACE_HUB_CACHE="${hf_path}"
if [ -n "${torch_arch}" ]; then
  export TORCH_CUDA_ARCH_LIST="${torch_arch}"
fi
echo "ML environment activated:"
echo "  - Virtual env: ${VENV_PATH}"
echo "  - HF_HOME: ${hf_path}"
if [ -n "${torch_arch}" ]; then
  echo "  - TORCH_CUDA_ARCH_LIST: ${torch_arch}"
fi
echo "  - Python: \$(python --version)"
EOF
  chmod +x "${VENV_PATH}/activate_ml"

  export HF_HOME="${hf_path}"
  export HUGGINGFACE_HUB_CACHE="${hf_path}"
  if [ -n "${torch_arch}" ]; then
    export TORCH_CUDA_ARCH_LIST="${torch_arch}"
  fi

  mkdir -p "${hf_path}" /workspace/scripts /workspace/logs || true
}

step1_activate_env() {
  # 1) Init/activate env and set CUDA paths
  step0_init_env

  export CUDA_HOME
  export PATH="${CUDA_HOME}/bin:${CUDA_HOME}/nvvm/bin:${PATH}"
  export LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH:-}"

  nvcc --version
  python -V
}

step0_init_env() {
  # Init mode: create env if missing (with HF prompt), else just activate.
  bootstrap_env_if_missing

  if [ -f "${VENV_PATH}/activate_ml" ]; then
    # shellcheck disable=SC1090
    source "${VENV_PATH}/activate_ml"
  else
    # shellcheck disable=SC1090
    source "${VENV_PATH}/bin/activate"
  fi
}

step2_install_parity_packages() {
  # 2) Install Docker-parity package set (UV pip)

  # Core SGLang + PyTorch cu130
  uv pip install --reinstall "sglang[all] @ git+https://github.com/sgl-project/sglang.git@${SGLANG_COMMIT}#subdirectory=python" \
    --index-url https://download.pytorch.org/whl/cu130 \
    --extra-index-url https://pypi.org/simple \
    --index-strategy unsafe-first-match

  uv pip install --reinstall torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1 \
    --index-url https://download.pytorch.org/whl/cu130

  # FlashInfer stack
  uv pip install --reinstall --no-deps flashinfer-python==0.6.3 flashinfer-cubin==0.6.3
  uv pip install --reinstall --no-deps flashinfer-jit-cache==0.6.3+cu130 \
    --index-url https://flashinfer.ai/whl/cu130 \
    --extra-index-url https://pypi.org/simple

  # sgl-kernel
  uv pip install --reinstall --no-deps \
    "https://github.com/sgl-project/whl/releases/download/v0.3.21/sgl_kernel-0.3.21+cu130-cp310-abi3-manylinux2014_${ARCH}.whl"

  # CUDA runtime libs used in parity env
  # Keep these on the cu130 index
  uv pip install --reinstall --no-deps \
    nvidia-cublas==13.1.0.3 \
    nixl-cu13==0.10.0 \
    cuda-python==13.1.1 \
    --index-url https://download.pytorch.org/whl/cu130 \
    --extra-index-url https://pypi.org/simple \
    --index-strategy first-index

  # Install these from PyPI to ensure component runtime libs are present
  # under site-packages/nvidia/{cudnn,nccl,cusparselt,nvshmem}/lib
  uv pip install --reinstall --no-deps \
    nvidia-cudnn-cu13==9.16.0.29 \
    nvidia-nccl-cu13==2.28.3 \
    nvidia-cusparselt-cu13==0.8.0 \
    nvidia-nvshmem-cu13==3.3.24 \
    --index-url https://pypi.org/simple

  # Explicitly pin model-runtime extras used by Kimi route.
  # Keep --no-deps so these cannot pull torch/triton/transformers off the cu130 stack.
  uv pip install --reinstall --no-deps xgrammar==0.1.27 compressed-tensors==0.13.0

  # Defensive parity check: ensure torch stays on the cu130 build before deep-ep build.
  local torch_cuda
  torch_cuda="$(python - <<'PY'
import torch
print(torch.version.cuda or "")
PY
)"
  if [ "${torch_cuda}" != "13.0" ]; then
    echo "Detected torch CUDA '${torch_cuda}', re-pinning to cu130..."
    uv pip install --reinstall torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1 \
      --index-url https://download.pytorch.org/whl/cu130
  fi

  # deep-ep wheel can be unavailable on Python 3.12; use source fallback if needed
  if ! uv pip install --reinstall deep-ep==1.2.1; then
    DEEPEP_SRC=/tmp/DeepEP-9af0e0d0e74f3577af1979c9b9e1ac2cad0104ee
    if [ ! -d "${DEEPEP_SRC}" ]; then
      git clone https://github.com/deepseek-ai/DeepEP.git "${DEEPEP_SRC}"
    fi
    git -C "${DEEPEP_SRC}" checkout 9af0e0d0e74f3577af1979c9b9e1ac2cad0104ee

    # CUDA 13 + current NVSHMEM headers can require CCCL headers (cuda/std/*).
    # Inject CUDA's CCCL include dir into DeepEP setup.py if present.
    if [ -d "${CUDA_HOME}/include/cccl" ] && ! rg -q "include_dirs\\.append\\('${CUDA_HOME}/include/cccl'\\)" "${DEEPEP_SRC}/setup.py"; then
      sed -i "/include_dirs.extend(\\[f'{nvshmem_dir}\\/include'\\])/i\\        include_dirs.append('${CUDA_HOME}/include/cccl')" "${DEEPEP_SRC}/setup.py"
    fi

    TORCH_CUDA_ARCH_LIST='9.0;10.0;10.3' uv pip install --reinstall --no-build-isolation --no-deps "${DEEPEP_SRC}"
  fi

  # Remove accidental cu12 leftovers if present
  uv pip uninstall \
    nvidia-cublas-cu12 nvidia-cuda-cupti-cu12 nvidia-cuda-nvrtc-cu12 nvidia-cuda-runtime-cu12 \
    nvidia-cudnn-cu12 nvidia-cufft-cu12 nvidia-cufile-cu12 nvidia-curand-cu12 nvidia-cusolver-cu12 \
    nvidia-cusparse-cu12 nvidia-cusparselt-cu12 nvidia-nccl-cu12 nvidia-nvjitlink-cu12 \
    nvidia-nvshmem-cu12 nvidia-nvtx-cu12 || true

  # Re-assert cu13 shared-library packages after cu12 cleanup.
  # Some package managers may remove shared nvidia/* paths during cu12 uninstall.
  uv pip install --reinstall --no-deps \
    nvidia-cudnn-cu13==9.16.0.29 \
    nvidia-nccl-cu13==2.28.3 \
    nvidia-cusparselt-cu13==0.8.0 \
    nvidia-nvshmem-cu13==3.3.24 \
    --index-url https://pypi.org/simple

  uv pip install --reinstall --no-deps \
    nvidia-cublas==13.1.0.3 \
    --index-url https://download.pytorch.org/whl/cu130 \
    --extra-index-url https://pypi.org/simple \
    --index-strategy first-index
}

step3_runtime_parity_fixes() {
  # 3) Runtime parity fixes

  # Docker image exposes libmlx5.so; match that on host
  local mlx_target="/usr/lib/$(uname -m)-linux-gnu/libmlx5.so.1"
  local mlx_link="/usr/lib/$(uname -m)-linux-gnu/libmlx5.so"
  if command -v sudo >/dev/null 2>&1; then
    sudo ln -sfn "${mlx_target}" "${mlx_link}"
  else
    ln -sfn "${mlx_target}" "${mlx_link}"
  fi
  ls -l "${mlx_link}"
}

step4_verify_versions_and_libs() {
  # 4) Verify important package versions
  for p in sglang torch triton transformers deep-ep flashinfer-python sgl-kernel xgrammar compressed-tensors; do
    python -c 'import importlib.metadata as m,sys; p=sys.argv[1]; print(f"{p}=={m.version(p)}")' "${p}" || echo "${p}==<missing>"
  done

  # Expected key versions:
  # - sglang from commit c3d78ded2ebf0c38abdde0266a31a2a147a9b9cb
  #   (package version may show as 0.5.6.post2 in this install path)
  # - torch==2.9.1+cu130
  # - triton==3.5.1
  # - transformers==4.57.1
  # - deep-ep==1.2.1
  # - flashinfer-python==0.6.3
  # - sgl-kernel==0.3.21

  # Critical shared-lib sanity check
  SITE_PKGS="$(python -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"
  find "${SITE_PKGS}" \( \
    -name 'libcusparseLt.so.0' -o \
    -name 'libnvshmem_host.so.3' -o \
    -name 'libnccl.so.2' -o \
    -name 'libcudnn.so.9' \
  \) -print

  # Hard-fail if any critical runtime .so is missing.
  python - <<'PY'
from pathlib import Path
import sysconfig

site = Path(sysconfig.get_paths()["purelib"])
required = [
    "libcusparseLt.so.0",
    "libnvshmem_host.so.3",
    "libnccl.so.2",
    "libcudnn.so.9",
]
missing = [name for name in required if not any(site.rglob(name))]
if missing:
    raise SystemExit(f"Missing required CUDA runtime libs: {', '.join(missing)}")
PY
}

step5_launch_server() {
  # 5) Launch command that avoids the slow-start trap
  # Important: do NOT force DeepGEMM flags here. Match Docker launch semantics.

  # Preflight launch deps. Launch should not install packages; fail fast if missing.
  local missing
  missing="$(python - <<'PY'
import importlib.util
mods = ("sglang", "IPython.display", "pydantic_core", "torch")
missing = [m for m in mods if importlib.util.find_spec(m) is None]
print(" ".join(missing))
PY
)"
  if [ -n "${missing}" ]; then
    echo "Launch dependency preflight failed. Missing: ${missing}"
    echo "Run: ./scripts/kimik25_rtxpro6000.sh install"
    exit 1
  fi

  # Critical fix: neutralize inherited high-thread BLAS/OMP env
  unset OMP_NUM_THREADS MKL_NUM_THREADS OPENBLAS_NUM_THREADS NUMEXPR_NUM_THREADS VECLIB_MAXIMUM_THREADS OMP_PLACES OMP_PROC_BIND
  export OMP_NUM_THREADS=1
  export MKL_NUM_THREADS=1
  export OPENBLAS_NUM_THREADS=1
  export NUMEXPR_NUM_THREADS=1
  export VECLIB_MAXIMUM_THREADS=1

  rm -f "${LOG}"

  python -m sglang.launch_server \
    --model-path "${MODEL_PATH}" \
    --served-model-name "${SERVED_MODEL_NAME}" \
    --tp "${TP}" \
    --trust-remote-code \
    --tool-call-parser kimi_k2 \
    --reasoning-parser kimi_k2 \
    --disable-radix-cache \
    --disable-chunked-prefix-cache \
    --api-key "${API_KEY}" \
    --host "${HOST}" \
    --port "${PORT}" \
    --show-time-cost \
    2>&1 | awk '{ print strftime("%F %T"), $0; fflush(); }' | tee "${LOG}"
}

step6_timing_check() {
  # 6) Timing check (post-shard to ready)
  python - <<'PY'
import re
from datetime import datetime
import os

log = os.environ.get("LOG", "/tmp/sglang_uv_kimi_fast.log")
fmt = "%Y-%m-%d %H:%M:%S"
cur = None
t100 = None
tready = None

with open(log, "r", errors="ignore") as f:
    for line in f:
        m = re.match(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s", line)
        if m:
            cur = datetime.strptime(m.group(1), fmt)
        if t100 is None and "Loading safetensors checkpoint shards: 100% Completed" in line:
            t100 = cur
        if tready is None and "Uvicorn running on" in line:
            tready = cur

print("t100:", t100)
print("tready:", tready)
if t100 and tready:
    print("seconds_100_to_ready:", int((tready - t100).total_seconds()))
PY

  # Expected:
  # - seconds_100_to_ready < 300 (target)
  # - On this machine after fix: about 87-98 seconds.
}

step7_if_still_slow() {
  # 7) If still slow
  env | rg '^(OMP_NUM_THREADS|MKL_NUM_THREADS|OPENBLAS_NUM_THREADS|NUMEXPR_NUM_THREADS|VECLIB_MAXIMUM_THREADS|OMP_PLACES|OMP_PROC_BIND)='

  # If any are high/non-empty from shell startup files, clear them before launch exactly as in step 5.
}

usage() {
  cat <<'USAGE'
Usage:
  kimik25_rtxpro6000.sh init       # create/activate env; opens activated subshell
  kimik25_rtxpro6000.sh all        # steps 1-5 (installs + launch, then blocks in server)
  kimik25_rtxpro6000.sh install    # steps 1-4 only
  kimik25_rtxpro6000.sh launch     # step 1 + step 5 only
  kimik25_rtxpro6000.sh timing     # step 6 only (reads LOG)
  kimik25_rtxpro6000.sh check-env  # step 7 only

Optional env overrides:
  VENV_PATH, CUDA_HOME, MODEL_PATH, SGLANG_COMMIT, API_KEY, HOST, PORT,
  SERVED_MODEL_NAME, TP, LOG, ARCH
USAGE
}

main() {
  local mode="${1:-launch}"

  case "${mode}" in
    init)
      step0_init_env
      # If run as a script (not sourced), activation cannot persist in parent shell.
      # Open an interactive subshell so user lands in an activated environment.
      if [ "${IS_SOURCED}" -eq 0 ] && [ "${INIT_SPAWN_SHELL:-1}" = "1" ]; then
        if [ -t 0 ] && [ -t 1 ]; then
          echo "Opening activated shell at ${VENV_PATH}. Exit to return."
          exec "${SHELL:-/bin/bash}" -i
        else
          echo "Environment initialized and activated for this process only."
          echo "To activate in your current shell: source \"${VENV_PATH}/activate_ml\""
        fi
      fi
      ;;
    all)
      step1_activate_env
      step2_install_parity_packages
      step3_runtime_parity_fixes
      step4_verify_versions_and_libs
      step5_launch_server
      ;;
    install|instal)
      step1_activate_env
      step2_install_parity_packages
      step3_runtime_parity_fixes
      step4_verify_versions_and_libs
      ;;
    launch)
      step1_activate_env
      step5_launch_server
      ;;
    timing)
      step6_timing_check
      ;;
    check-env)
      step7_if_still_slow
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
