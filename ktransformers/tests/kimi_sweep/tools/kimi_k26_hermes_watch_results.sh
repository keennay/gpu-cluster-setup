#!/usr/bin/env bash
set -euo pipefail

tool_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
plan_dir="$(cd -- "${tool_dir}/.." && pwd)"
repo_root="${KT_REPO_ROOT:-$(cd -- "${plan_dir}/../.." && pwd)}"
cd "${repo_root}"

KT_EXPERTS_PATH="${KT_EXPERTS_PATH:-kimi_k26/h200x2}"
KT_BENCHMARK_SEED="${KT_BENCHMARK_SEED:-52}"
KT_SWEEP_NUM_PROMPTS="${KT_SWEEP_NUM_PROMPTS:-100}"
RESULTS_DIR="${RESULTS_DIR:-${repo_root}/results/${KT_EXPERTS_PATH}/tests}"
KT_HERMES_NOTIFY="${KT_HERMES_NOTIFY:-1}"
KT_HERMES_NOTIFY_STATE="${KT_HERMES_NOTIFY_STATE:-/tmp/kimi_k26_seed${KT_BENCHMARK_SEED}_hermes_notified_tests.txt}"
KT_HERMES_WATCH_INTERVAL="${KT_HERMES_WATCH_INTERVAL:-30}"
KT_HERMES_WATCH_MARK_EXISTING="${KT_HERMES_WATCH_MARK_EXISTING:-1}"

mkdir -p "$(dirname "${KT_HERMES_NOTIFY_STATE}")"
touch "${KT_HERMES_NOTIFY_STATE}"

successful_result() {
  local out="$1"
  [[ -f "${out}" ]] || return 1
  grep -q '^END_UTC:' "${out}" || return 1
  grep -q '^BENCHMARK_EXIT_CODE: 0' "${out}" || return 1
  grep -Eq "Successful requests:[[:space:]]+${KT_SWEEP_NUM_PROMPTS}/${KT_SWEEP_NUM_PROMPTS}" "${out}" || return 1
}

result_metrics_line() {
  local result_file="$1"
  local test_name="$2"
  python - "${result_file}" "${test_name}" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
test_name = sys.argv[2]
txt = path.read_text(errors="replace")

chunk = re.search(r"--chunked-prefill-size\s+(\S+)", txt)
threshold = re.search(r"--kt-gpu-prefill-token-threshold\s+(\S+)", txt)
output = re.search(r"^  Output tokens/sec:\s*([0-9.]+)", txt, re.M)
ttft = re.search(
    r"^Reasoning:\n  Mean:\s*([0-9]+)ms\n  Median:\s*([0-9]+)ms\n  P95:\s*([0-9]+)ms",
    txt,
    re.M,
)
if not ttft:
    sys.exit(1)

print(
    "\t".join(
        [
            test_name,
            chunk.group(1) if chunk else "n/a",
            threshold.group(1) if threshold else "n/a",
            output.group(1) if output else "n/a",
            f"{int(ttft.group(1)) / 1000:.3f}s",
            f"{int(ttft.group(2)) / 1000:.3f}s",
            f"{int(ttft.group(3)) / 1000:.3f}s",
        ]
    )
)
PY
}

best_result_metrics_line() {
  python - "${RESULTS_DIR}" "${KT_SWEEP_NUM_PROMPTS}" <<'PY'
import re
import sys
from pathlib import Path

results_dir = Path(sys.argv[1])
expected_requests = sys.argv[2]
rows = []

for path in sorted(results_dir.glob("test*.txt")):
    txt = path.read_text(errors="replace")
    if "BENCHMARK_EXIT_CODE: 0" not in txt:
        continue
    if not re.search(rf"Successful requests:\s+{expected_requests}/{expected_requests}", txt):
        continue
    ttft = re.search(
        r"^Reasoning:\n  Mean:\s*([0-9]+)ms\n  Median:\s*([0-9]+)ms\n  P95:\s*([0-9]+)ms",
        txt,
        re.M,
    )
    if not ttft:
        continue
    mean_ms = int(ttft.group(1))
    median_ms = int(ttft.group(2))
    p95_ms = int(ttft.group(3))
    chunk = re.search(r"--chunked-prefill-size\s+(\S+)", txt)
    threshold = re.search(r"--kt-gpu-prefill-token-threshold\s+(\S+)", txt)
    output = re.search(r"^  Output tokens/sec:\s*([0-9.]+)", txt, re.M)
    output_toks = float(output.group(1)) if output else 0.0
    rows.append(
        {
            "mean_ms": mean_ms,
            "median_ms": median_ms,
            "p95_ms": p95_ms,
            "output_toks": output_toks,
            "output_text": output.group(1) if output else "n/a",
            "test_name": path.stem,
            "chunk": chunk.group(1) if chunk else "n/a",
            "threshold": threshold.group(1) if threshold else "n/a",
        }
    )

if not rows:
    sys.exit(1)

min_mean = min(row["mean_ms"] for row in rows)
ttft_tolerance_ms = max(250, int(min_mean * 0.005))
eligible = [row for row in rows if row["mean_ms"] <= min_mean + ttft_tolerance_ms]
best = sorted(
    eligible,
    key=lambda row: (
        -row["output_toks"],
        row["p95_ms"],
        row["median_ms"],
        row["mean_ms"],
        row["test_name"],
    ),
)[0]

print(
    "\t".join(
        [
            best["test_name"],
            best["chunk"],
            best["threshold"],
            best["output_text"],
            f'{best["mean_ms"] / 1000:.3f}s',
            f'{best["median_ms"] / 1000:.3f}s',
            f'{best["p95_ms"] / 1000:.3f}s',
        ]
    )
)
PY
}

hermes_send_discord() {
  local message="$1"

  if [[ "${KT_HERMES_NOTIFY}" != "1" ]]; then
    return 0
  fi
  if ! command -v hermes >/dev/null 2>&1; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] HERMES_NOTIFY_SKIP hermes_not_found"
    return 0
  fi

  if ! hermes send --quiet --to discord "${message}" >/dev/null 2>&1; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] HERMES_NOTIFY_FAIL ${message}"
  fi
}

notify_file() {
  local out="$1"
  local test_name
  local metrics
  local best
  local chunk threshold output_toks mean_ttft median_ttft p95

  test_name="$(basename "${out}" .txt)"
  if grep -qx "${test_name}" "${KT_HERMES_NOTIFY_STATE}" 2>/dev/null; then
    return 0
  fi
  successful_result "${out}" || return 0

  metrics="$(result_metrics_line "${out}" "${test_name}" 2>/dev/null)" || return 0
  IFS=$'\t' read -r test_name chunk threshold output_toks mean_ttft median_ttft p95 <<< "${metrics}"
  hermes_send_discord "${test_name}: Complete | Chunk: ${chunk} | Threshold: ${threshold} | Output Toks/s: ${output_toks} | Mean TTFT: ${mean_ttft} | Median TTFT: ${median_ttft} | P95: ${p95}"

  best="$(best_result_metrics_line 2>/dev/null)" || return 0
  IFS=$'\t' read -r test_name chunk threshold output_toks mean_ttft median_ttft p95 <<< "${best}"
  hermes_send_discord "Best So far is ${test_name} | Chunk: ${chunk} | Threshold: ${threshold} | Output Toks/s: ${output_toks} | Mean TTFT: ${mean_ttft} | Median TTFT: ${median_ttft} | P95: ${p95}"

  printf '%s\n' "$(basename "${out}" .txt)" >> "${KT_HERMES_NOTIFY_STATE}"
}

if [[ "${KT_HERMES_WATCH_MARK_EXISTING}" == "1" ]]; then
  for out in "${RESULTS_DIR}"/test*.txt; do
    [[ -e "${out}" ]] || continue
    successful_result "${out}" || continue
    test_name="$(basename "${out}" .txt)"
    grep -qx "${test_name}" "${KT_HERMES_NOTIFY_STATE}" 2>/dev/null || printf '%s\n' "${test_name}" >> "${KT_HERMES_NOTIFY_STATE}"
  done
fi

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] HERMES_WATCH_START results=${RESULTS_DIR} state=${KT_HERMES_NOTIFY_STATE}"
while true; do
  for out in "${RESULTS_DIR}"/test*.txt; do
    [[ -e "${out}" ]] || continue
    notify_file "${out}"
  done
  sleep "${KT_HERMES_WATCH_INTERVAL}"
done
