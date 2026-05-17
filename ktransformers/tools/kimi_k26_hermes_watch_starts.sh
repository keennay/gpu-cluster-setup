#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${script_dir}"

KT_BENCHMARK_SEED="${KT_BENCHMARK_SEED:-52}"
KT_PLAN_FILE="${KT_PLAN_FILE:-kimi_k26_sweep.md}"
KT_HERMES_NOTIFY="${KT_HERMES_NOTIFY:-1}"
KT_HERMES_START_NOTIFY_STATE="${KT_HERMES_START_NOTIFY_STATE:-/tmp/kimi_k26_seed${KT_BENCHMARK_SEED}_hermes_started_tests.txt}"
KT_HERMES_START_FROM="${KT_HERMES_START_FROM:-025}"
KT_HERMES_START_WATCH_LOG="${KT_HERMES_START_WATCH_LOG:-/tmp/kimi_k26_seed52_workflow.log}"
KT_HERMES_START_WATCH_INTERVAL="${KT_HERMES_START_WATCH_INTERVAL:-10}"

COMMON="--tool-call-parser kimi_k2 --reasoning-parser kimi_k2 --max-running-requests 2 --max-total-tokens 131072"
GRAPH2="--cuda-graph-max-bs 2 --cuda-graph-bs 1 2"
GRAPH4="--cuda-graph-max-bs 4 --cuda-graph-bs 1 2 4"
GRAPH8="--cuda-graph-max-bs 8 --cuda-graph-bs 1 2 4 8"
FAST_BACKEND="--disable-custom-all-reduce"
NVLS="--enable-nccl-nvls"
FLASHINFER_BACKEND="--prefill-attention-backend flashinfer --decode-attention-backend flashinfer --sampling-backend flashinfer"
TRITON_PREFILL_BACKEND="--prefill-attention-backend triton --decode-attention-backend fa3 --sampling-backend flashinfer"

hermes_send_discord() {
  local message="$1"

  if [[ "${KT_HERMES_NOTIFY}" != "1" ]]; then
    return 0
  fi
  if ! command -v hermes >/dev/null 2>&1; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] HERMES_START_SKIP hermes_not_found"
    return 0
  fi

  if ! hermes send --quiet --to discord "${message}" >/dev/null 2>&1; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] HERMES_START_FAIL ${message}"
  fi
}

arg_value() {
  local flag="$1"
  shift

  while (( $# > 0 )); do
    if [[ "$1" == "${flag}" ]]; then
      shift
      if (( $# > 0 )); then
        printf '%s\n' "$1"
        return 0
      fi
      return 1
    fi
    shift
  done
  return 1
}

arg_present() {
  local flag="$1"
  shift

  while (( $# > 0 )); do
    if [[ "$1" == "${flag}" ]]; then
      return 0
    fi
    shift
  done
  return 1
}

join_by() {
  local sep="$1"
  shift

  if (( $# == 0 )); then
    return 0
  fi

  printf '%s' "$1"
  shift || true
  while (( $# > 0 )); do
    printf '%s%s' "${sep}" "$1"
    shift
  done
}

test_start_explainer() {
  local label="$1"
  local kt_cpuinfer="$2"
  local kt_threadpool_count="$3"
  local kt_num_gpu_experts="$4"
  local kt_deferred="$5"
  local mem_fraction_static="$6"
  local chunked_prefill_size="$7"
  local extra_args="$8"
  local -a args=()
  local -a notes=()
  local threshold graph_max max_run max_total max_prefill prefill_max_requests schedule prefill_backend decode_backend sampling_backend tokenizer_workers

  read -r -a args <<< "${extra_args}"
  threshold="$(arg_value --kt-gpu-prefill-token-threshold "${args[@]}" || true)"
  graph_max="$(arg_value --cuda-graph-max-bs "${args[@]}" || true)"
  max_run="$(arg_value --max-running-requests "${args[@]}" || true)"
  max_total="$(arg_value --max-total-tokens "${args[@]}" || true)"
  max_prefill="$(arg_value --max-prefill-tokens "${args[@]}" || true)"
  prefill_max_requests="$(arg_value --prefill-max-requests "${args[@]}" || true)"
  schedule="$(arg_value --schedule-policy "${args[@]}" || true)"
  prefill_backend="$(arg_value --prefill-attention-backend "${args[@]}" || true)"
  decode_backend="$(arg_value --decode-attention-backend "${args[@]}" || true)"
  sampling_backend="$(arg_value --sampling-backend "${args[@]}" || true)"
  tokenizer_workers="$(arg_value --tokenizer-worker-num "${args[@]}" || true)"

  [[ -n "${graph_max}" ]] && notes+=("cuda_graph_max_bs=${graph_max}")
  arg_present --disable-cuda-graph "${args[@]}" && notes+=("cuda_graph=off")
  arg_present --disable-cuda-graph-padding "${args[@]}" && notes+=("graph_padding=off")
  arg_present --enable-piecewise-cuda-graph "${args[@]}" && notes+=("piecewise_graph")
  arg_present --disable-custom-all-reduce "${args[@]}" && notes+=("fast_backend/no_custom_allreduce")
  arg_present --enable-nccl-nvls "${args[@]}" && notes+=("NVLS")
  arg_present --enable-flashinfer-allreduce-fusion "${args[@]}" && notes+=("flashinfer_allreduce")
  arg_present --kt-enable-dynamic-expert-update "${args[@]}" && notes+=("dynamic_expert_update")
  arg_present --enable-symm-mem "${args[@]}" && notes+=("symm_mem")
  arg_present --enable-tokenizer-batch-encode "${args[@]}" && notes+=("tokenizer_batch_encode")
  [[ -n "${prefill_backend}" ]] && notes+=("prefill=${prefill_backend}")
  [[ -n "${decode_backend}" ]] && notes+=("decode=${decode_backend}")
  [[ -n "${sampling_backend}" ]] && notes+=("sampling=${sampling_backend}")
  [[ -n "${max_run}" ]] && notes+=("max_run=${max_run}")
  [[ -n "${max_total}" ]] && notes+=("max_total=${max_total}")
  [[ -n "${max_prefill}" ]] && notes+=("max_prefill=${max_prefill}")
  [[ -n "${prefill_max_requests}" ]] && notes+=("prefill_max_requests=${prefill_max_requests}")
  [[ -n "${schedule}" ]] && notes+=("schedule=${schedule}")
  [[ -n "${tokenizer_workers}" ]] && notes+=("tokenizer_workers=${tokenizer_workers}")

  printf 'label=%s; chunk=%s; threshold=%s; mem=%s; gpu_experts=%s; cpuinfer=%s; threadpools=%s; deferred=%s' \
    "${label}" \
    "${chunked_prefill_size}" \
    "${threshold:-n/a}" \
    "${mem_fraction_static}" \
    "${kt_num_gpu_experts}" \
    "${kt_cpuinfer}" \
    "${kt_threadpool_count}" \
    "${kt_deferred}"

  if (( ${#notes[@]} > 0 )); then
    printf '; flags=%s' "$(join_by ', ' "${notes[@]}")"
  fi
}

mark_start_notified() {
  local id="$1"
  local key="test${id}"
  local fd

  mkdir -p "$(dirname "${KT_HERMES_START_NOTIFY_STATE}")"
  touch "${KT_HERMES_START_NOTIFY_STATE}"

  if command -v flock >/dev/null 2>&1; then
    exec {fd}>"${KT_HERMES_START_NOTIFY_STATE}.lock"
    flock -x "${fd}" || return 1
    if grep -qx "${key}" "${KT_HERMES_START_NOTIFY_STATE}" 2>/dev/null; then
      flock -u "${fd}" || true
      return 1
    fi
    printf '%s\n' "${key}" >> "${KT_HERMES_START_NOTIFY_STATE}"
    flock -u "${fd}" || true
    return 0
  fi

  if grep -qx "${key}" "${KT_HERMES_START_NOTIFY_STATE}" 2>/dev/null; then
    return 1
  fi
  printf '%s\n' "${key}" >> "${KT_HERMES_START_NOTIFY_STATE}"
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
  local id_num start_from_num explainer

  id_num=$((10#${id}))
  start_from_num=$((10#${KT_HERMES_START_FROM}))
  if (( id_num < start_from_num )); then
    return 0
  fi

  if ! mark_start_notified "${id}"; then
    return 0
  fi

  explainer="$(test_start_explainer \
    "${label}" \
    "${kt_cpuinfer}" \
    "${kt_threadpool_count}" \
    "${kt_num_gpu_experts}" \
    "${kt_deferred}" \
    "${mem_fraction_static}" \
    "${chunked_prefill_size}" \
    "${extra_args}")"
  hermes_send_discord "Starting test${id} | ${explainer}"
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] HERMES_START_SENT test${id}"
}

notify_started_test() {
  local id="$1"
  local line

  [[ -f "${KT_PLAN_FILE}" ]] || return 0
  line="$(awk -v id="${id}" '$1 == "run_test" && $2 == id {print; exit}' "${KT_PLAN_FILE}")"
  [[ -n "${line}" ]] || return 0
  eval "${line}"
}

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] HERMES_START_WATCH_START log=${KT_HERMES_START_WATCH_LOG} state=${KT_HERMES_START_NOTIFY_STATE}"
while true; do
  if [[ -f "${KT_HERMES_START_WATCH_LOG}" ]]; then
    while IFS= read -r id; do
      notify_started_test "${id}"
    done < <(grep -Eo 'START test[0-9]{3}_[^ ]+' "${KT_HERMES_START_WATCH_LOG}" 2>/dev/null | sed -E 's/START test([0-9]{3})_.*/\1/' | sort -u)
  fi
  sleep "${KT_HERMES_START_WATCH_INTERVAL}"
done
