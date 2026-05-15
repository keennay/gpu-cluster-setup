#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$script_dir"

KT_EXPERTS_PATH="${KT_EXPERTS_PATH:-kimi_k26/h200x2}"
KT_PYTHON_ENV="${KT_PYTHON_ENV:-${HOME}/env_qwen3-ktransformers}"
KT_TEST_ENV="${KT_TEST_ENV:-./envs/${KT_EXPERTS_PATH}.env}"
KT_BENCHMARK_MODEL="${KT_BENCHMARK_MODEL:-kimi_k2}"
KT_BENCHMARK_PATH="${KT_BENCHMARK_PATH:-/workspace/scripts/benchmark.py}"
KT_BENCHMARK_SEED="${KT_BENCHMARK_SEED:-52}"
KT_RECORD_NUM_PROMPTS="${KT_RECORD_NUM_PROMPTS:-100}"
KT_SWEEP_NUM_PROMPTS="${KT_SWEEP_NUM_PROMPTS:-100}"
KT_CONCURRENCY="${KT_CONCURRENCY:-2}"
KT_TIMEOUT="${KT_TIMEOUT:-3600}"
RESULTS_DIR="${RESULTS_DIR:-./results/${KT_EXPERTS_PATH}/tests}"
MAX_TEST_ATTEMPTS="${MAX_TEST_ATTEMPTS:-3}"
GPU_CLEANUP_TIMEOUT_SECONDS="${GPU_CLEANUP_TIMEOUT_SECONDS:-180}"
GPU_CLEANUP_POLL_SECONDS="${GPU_CLEANUP_POLL_SECONDS:-5}"
GPU_CLEANUP_EXTRA_SLEEP_SECONDS="${GPU_CLEANUP_EXTRA_SLEEP_SECONDS:-10}"
KT_HOST="${KT_HOST:-0.0.0.0}"
KT_PORT="${KT_PORT:-8000}"
KT_API_KEY="${KT_API_KEY:-YOUR_API_KEY}"
KT_READY_URL="${KT_READY_URL:-http://127.0.0.1:${KT_PORT}/v1/models}"

if [[ -d "${KT_PYTHON_ENV}" ]]; then
  # shellcheck disable=SC1091
  source "${KT_PYTHON_ENV}/bin/activate"
fi

# shellcheck source=tools/launch_config.sh
source ./tools/launch_config.sh
load_launch_config "${KT_TEST_ENV}"

mkdir -p "${RESULTS_DIR}" "./experts/${EXPERTS_PATH}/01" "./experts/${EXPERTS_PATH}/02"

sglang_process_pids() {
  pgrep -f "python -m sglang.launch_server|sglang::scheduler|sglang::detokenizer|sglang::tokenizer" 2>/dev/null || true
}

sglang_gpu_processes() {
  command -v nvidia-smi >/dev/null 2>&1 || return 0
  nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader,nounits 2>/dev/null \
    | awk '/sglang::|sglang.launch_server/'
}

wait_for_no_sglang_processes() {
  local deadline=$((SECONDS + GPU_CLEANUP_TIMEOUT_SECONDS))
  while [[ "${SECONDS}" -lt "${deadline}" ]]; do
    if [[ -z "$(sglang_process_pids)" ]] && [[ -z "$(sglang_gpu_processes)" ]]; then
      return 0
    fi
    sleep "${GPU_CLEANUP_POLL_SECONDS}"
  done
  return 1
}

cleanup_server() {
  pkill -TERM -f "python -m sglang.launch_server" 2>/dev/null || true
  pkill -TERM -f "sglang.launch_server|sglang::scheduler|sglang::detokenizer|sglang::tokenizer" 2>/dev/null || true

  if ! wait_for_no_sglang_processes; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] CLEANUP_FORCE_KILL remaining_sglang_processes"
    sglang_process_pids | xargs -r kill -KILL 2>/dev/null || true
    pkill -KILL -f "python -m sglang.launch_server" 2>/dev/null || true
    pkill -KILL -f "sglang.launch_server|sglang::scheduler|sglang::detokenizer|sglang::tokenizer" 2>/dev/null || true
    wait_for_no_sglang_processes || {
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] CLEANUP_STILL_BUSY"
      sglang_gpu_processes || true
    }
  fi

  sleep "${GPU_CLEANUP_EXTRA_SLEEP_SECONDS}"
}

wait_for_server() {
  local pid="$1"
  local out="$2"
  local server_log="$3"

  for _ in $(seq 1 180); do
    if curl -fsS -H "Authorization: Bearer ${KT_API_KEY}" "${KT_READY_URL}" >/dev/null 2>&1; then
      return 0
    fi
    if ! kill -0 "${pid}" 2>/dev/null; then
      {
        echo
        echo "SERVER_EXITED_BEFORE_READY"
        echo "SERVER_LOG_TAIL:"
        tail -n 200 "${server_log}" || true
      } >> "${out}"
      return 1
    fi
    sleep 10
  done

  {
    echo
    echo "SERVER_READINESS_TIMEOUT"
    echo "SERVER_LOG_TAIL:"
    tail -n 200 "${server_log}" || true
  } >> "${out}"
  return 1
}

successful_result() {
  local out="$1"
  [[ -f "${out}" ]] || return 1
  grep -q '^END_UTC:' "${out}" || return 1
  grep -q '^BENCHMARK_EXIT_CODE: 0' "${out}" || return 1
  grep -Eq 'Successful requests:[[:space:]]+100/100' "${out}" || return 1
}

archive_failed_result() {
  local path="$1"
  [[ -e "${path}" ]] || return 0
  local stamp
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  mv "${path}" "${path}.previous_${stamp}"
}

latest_combined_expert() {
  local dir="$1"
  local path
  for path in "${dir}"/expert_distribution_recorder_*.pt; do
    [[ -e "${path}" ]] || continue
    local name timestamp gpu_path
    name="$(basename "${path}")"
    timestamp="${name#expert_distribution_recorder_}"
    timestamp="${timestamp%.pt}"
    gpu_path="${dir}/gpu_expert_distribution_${timestamp}.pt"
    if [[ ! -e "${gpu_path}" ]]; then
      printf '%s\n' "${path}"
    fi
  done | sort -V | tail -n 1
}

write_seed_profile() {
  local out="${RESULTS_DIR}/seed${KT_BENCHMARK_SEED}_profile.txt"
  python - "$KT_BENCHMARK_PATH" "$KT_BENCHMARK_SEED" > "${out}" <<'PY'
import importlib.util
import random
import statistics
import sys
from collections import Counter

path = sys.argv[1]
seed = int(sys.argv[2])
sys.argv = ["benchmark.py", "--preview-samples", "1", "--seed", str(seed)]
spec = importlib.util.spec_from_file_location("bench_sampler", path)
bench = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bench)

bench.RANDOM_SEED = seed
bench.seed_random()
rows = []
for _ in range(100):
    input_len, input_bucket = bench.sample_input_tokens()
    output_len, output_bucket = bench.sample_output_tokens()
    prompt = bench.generate_unique_prompt(input_len, input_bucket, output_bucket)
    random.uniform(0.15, 0.45)
    rows.append((input_len, output_len, input_bucket, output_bucket, max(1, len(prompt) // 4)))

input_counts = Counter(row[2] for row in rows)
output_counts = Counter(row[3] for row in rows)
print(f"SEED: {seed}")
print(f"AVG_INPUT_TARGET: {statistics.mean(row[0] for row in rows):.0f}")
print(f"AVG_INPUT_APPROX: {statistics.mean(row[4] for row in rows):.0f}")
print(f"AVG_OUTPUT_TARGET: {statistics.mean(row[1] for row in rows):.0f}")
print("INPUT_MIX:")
for name in ["small_bugfix", "feature_task", "refactor", "deep_repo_context"]:
    print(f"  {name}: {input_counts[name]}")
print("OUTPUT_MIX:")
for name in ["small_patch", "standard_patch", "large_patch"]:
    print(f"  {name}: {output_counts[name]}")
PY
}

run_record_stage() {
  local stage="$1"
  local script="$2"
  local combine_dir="$3"
  local out="${RESULTS_DIR}/${stage}_seed${KT_BENCHMARK_SEED}.txt"
  local server_log="${RESULTS_DIR}/${stage}_seed${KT_BENCHMARK_SEED}.server.log"

  if successful_result "${out}" && [[ -n "$(latest_combined_expert "${combine_dir}")" ]]; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] SKIP ${stage} already completed successfully"
    return 0
  fi
  archive_failed_result "${out}"
  archive_failed_result "${server_log}"
  : > "${out}"

  local -a server_cmd=(bash "${script}" "${KT_TEST_ENV}")
  local -a benchmark_cmd=(
    python "${KT_BENCHMARK_PATH}"
      --num-prompts "${KT_RECORD_NUM_PROMPTS}"
      --concurrency "${KT_CONCURRENCY}"
      --timeout "${KT_TIMEOUT}"
      --seed "${KT_BENCHMARK_SEED}"
      --model "${KT_BENCHMARK_MODEL}"
      --label "${KT_EXPERTS_PATH} | ${stage}_seed${KT_BENCHMARK_SEED}"
  )

  cleanup_server
  {
    echo "STAGE: ${stage}"
    echo "START_UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "SEED: ${KT_BENCHMARK_SEED}"
    echo
    echo "SERVER_COMMAND:"
    printf '%q ' "${server_cmd[@]}"
    echo
    echo
    echo "BENCHMARK_COMMAND:"
    printf '%q ' "${benchmark_cmd[@]}"
    echo
    echo
    echo "BENCHMARK_OUTPUT:"
  } >> "${out}"

  "${server_cmd[@]}" > "${server_log}" 2>&1 &
  local server_pid=$!
  if ! wait_for_server "${server_pid}" "${out}" "${server_log}"; then
    cleanup_server
    echo "BENCHMARK_EXIT_CODE: 97" >> "${out}"
    return 1
  fi

  set +e
  "${benchmark_cmd[@]}" >> "${out}" 2>&1
  local benchmark_rc=$?
  set -e

  cleanup_server
  {
    echo
    echo "BENCHMARK_EXIT_CODE: ${benchmark_rc}"
    echo "END_UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } >> "${out}"

  if (( benchmark_rc != 0 )); then
    return "${benchmark_rc}"
  fi

  python ./tools/combine_expert_distrbution_recordings.py "${combine_dir}" >> "${out}" 2>&1
}

refresh_latest_expert_location() {
  local recorder_dir="./experts/${EXPERTS_PATH}/02"
  latest_expert_location="$(latest_combined_expert "${recorder_dir}")"
  if [[ -z "${latest_expert_location}" ]]; then
    echo "No combined expert_distribution_recorder_*.pt files found in ${recorder_dir}" >&2
    exit 1
  fi
}

run_test() {
  local id="$1"
  local label="$2"
  local kt_cpuinfer="$3"
  local kt_threadpool_count="$4"
  local kt_num_gpu_experts="$5"
  local kt_deferred="$6"
  local mem_fraction_static="$7"
  local chunked_prefill_size="$8"
  local extra_args="$9"

  local out="${RESULTS_DIR}/test${id}.txt"
  local server_log="${RESULTS_DIR}/test${id}.server.log"
  local -a extra_arg_list=()
  read -r -a extra_arg_list <<< "${extra_args}"

  if successful_result "${out}"; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] SKIP test${id}_${label} already completed successfully"
    return 0
  fi

  archive_failed_result "${out}"
  archive_failed_result "${server_log}"

  local -a cmd=(
    env CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES}"
    "${ADDITIONAL_SGLANG_ENV_ARGS[@]}"
    numactl --cpunodebind="${NUMACTL_CPUNODEBIND}" --membind="${NUMACTL_MEMBIND}"
    python -m sglang.launch_server
      --host "${KT_HOST}"
      --port "${KT_PORT}"
      --api-key "${KT_API_KEY}"
      --model-path "${model_path}"
      --kt-weight-path "${model_path}"
      --kt-cpuinfer "${kt_cpuinfer}"
      --kt-threadpool-count "${kt_threadpool_count}"
      --kt-num-gpu-experts "${kt_num_gpu_experts}"
      --kt-method "${KT_METHOD}"
      --kt-max-deferred-experts-per-token "${kt_deferred}"
      --kt-expert-placement-strategy frequency
      --init-expert-location "${latest_expert_location}"
      --trust-remote-code
      --mem-fraction-static "${mem_fraction_static}"
      --chunked-prefill-size "${chunked_prefill_size}"
      --served-model-name "${SERVED_MODEL_NAME}"
      --enable-mixed-chunk
      --tensor-parallel-size "${TENSOR_PARALLEL_SIZE}"
      --numa-node "${NUMA_NODE_ARGS[@]}"
      --enable-p2p-check
      --disable-shared-experts-fusion
      --disable-radix-cache
      --disable-chunked-prefix-cache
      "${extra_arg_list[@]}"
  )

  local -a benchmark_cmd=(
    python "${KT_BENCHMARK_PATH}"
      --num-prompts "${KT_SWEEP_NUM_PROMPTS}"
      --concurrency "${KT_CONCURRENCY}"
      --timeout "${KT_TIMEOUT}"
      --seed "${KT_BENCHMARK_SEED}"
      --model "${KT_BENCHMARK_MODEL}"
      --label "${KT_EXPERTS_PATH} | test${id}_${label} | seed${KT_BENCHMARK_SEED}"
  )

  : > "${out}"
  local attempt
  for attempt in $(seq 1 "${MAX_TEST_ATTEMPTS}"); do
    cleanup_server
    if (( attempt > 1 )); then
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] RETRY test${id}_${label} attempt=${attempt}/${MAX_TEST_ATTEMPTS}"
      sleep 20
    fi
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] START test${id}_${label} attempt=${attempt}/${MAX_TEST_ATTEMPTS}"

    {
      echo "TEST: test${id}_${label}"
      echo "ATTEMPT: ${attempt}/${MAX_TEST_ATTEMPTS}"
      echo "START_UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
      echo "SEED: ${KT_BENCHMARK_SEED}"
      echo "EXPERT_FILE: ${latest_expert_location}"
      echo
      echo "SGLANG_COMMAND:"
      printf '%q ' "${cmd[@]}"
      echo
      echo
      echo "BENCHMARK_COMMAND:"
      printf '%q ' "${benchmark_cmd[@]}"
      echo
      echo
      echo "BENCHMARK_OUTPUT:"
    } >> "${out}"

    "${cmd[@]}" > "${server_log}" 2>&1 &
    local server_pid=$!
    if ! wait_for_server "${server_pid}" "${out}" "${server_log}"; then
      cleanup_server
      echo "ATTEMPT_RESULT: READY_FAIL" >> "${out}"
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] READY_FAIL test${id}_${label} attempt=${attempt}/${MAX_TEST_ATTEMPTS}"
      if (( attempt == MAX_TEST_ATTEMPTS )); then
        echo "BENCHMARK_EXIT_CODE: 98" >> "${out}"
        echo "END_UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "${out}"
        return 98
      fi
      archive_failed_result "${out}"
      archive_failed_result "${server_log}"
      : > "${out}"
      continue
    fi

    set +e
    "${benchmark_cmd[@]}" >> "${out}" 2>&1
    local benchmark_rc=$?
    set -e

    cleanup_server
    {
      echo
      echo "BENCHMARK_EXIT_CODE: ${benchmark_rc}"
      echo "END_UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } >> "${out}"

    if (( benchmark_rc == 0 )) && successful_result "${out}"; then
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] DONE test${id}_${label} benchmark_rc=${benchmark_rc} attempt=${attempt}/${MAX_TEST_ATTEMPTS}"
      return 0
    fi

    echo "ATTEMPT_RESULT: BENCHMARK_FAIL rc=${benchmark_rc}" >> "${out}"
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] BENCHMARK_FAIL test${id}_${label} benchmark_rc=${benchmark_rc} attempt=${attempt}/${MAX_TEST_ATTEMPTS}"
    if (( attempt == MAX_TEST_ATTEMPTS )); then
      return "${benchmark_rc:-1}"
    fi
    archive_failed_result "${out}"
    archive_failed_result "${server_log}"
  done
}

write_seed_profile
run_record_stage record01 ./02_record.sh "./experts/${EXPERTS_PATH}/01"
run_record_stage record02 ./03_record.sh "./experts/${EXPERTS_PATH}/02"
refresh_latest_expert_location

COMMON="--tool-call-parser kimi_k2 --reasoning-parser kimi_k2 --max-running-requests 2 --max-total-tokens 131072"
GRAPH2="--cuda-graph-max-bs 2 --cuda-graph-bs 1 2"
GRAPH4="--cuda-graph-max-bs 4 --cuda-graph-bs 1 2 4"
GRAPH8="--cuda-graph-max-bs 8 --cuda-graph-bs 1 2 4 8"
FAST_BACKEND="--disable-custom-all-reduce"
NVLS="--enable-nccl-nvls"
FLASHINFER_BACKEND="--prefill-attention-backend flashinfer --decode-attention-backend flashinfer --sampling-backend flashinfer"
TRITON_PREFILL_BACKEND="--prefill-attention-backend triton --decode-attention-backend fa3 --sampling-backend flashinfer"

mapfile -t PLAN_RUN_TESTS < <(awk '/^run_test [0-9][0-9][0-9] / {print}' kimi_k2.6.md)
if (( ${#PLAN_RUN_TESTS[@]} < 100 )); then
  echo "Expected at least 100 run_test lines in kimi_k2.6.md, found ${#PLAN_RUN_TESTS[@]}" >&2
  exit 2
fi

for plan_line in "${PLAN_RUN_TESTS[@]}"; do
  eval "${plan_line}"
done
