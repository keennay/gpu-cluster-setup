#!/usr/bin/env bash

sglang_log_key_from_config() {
  local script_dir="$1"
  local config_file="$2"
  local key="$config_file"

  key="${key#./}"
  if [[ "$key" == /* ]]; then
    local env_root="$script_dir/envs/"
    if [[ "$key" == "$env_root"* ]]; then
      key="${key#"$env_root"}"
    else
      key="${EXPERTS_PATH:-}"
    fi
  elif [[ "$key" == envs/* ]]; then
    key="${key#envs/}"
  fi

  key="${key%.env}"
  key="${key#/}"
  key="${key%/}"

  if [[ -z "$key" || "$key" == *".."* ]]; then
    key="${EXPERTS_PATH:-unknown}"
  fi

  printf '%s' "$key"
}

setup_sglang_launch_log() {
  local script_dir="$1"
  local script_label="$2"
  local config_file="${LAUNCH_CONFIG_FILE:-}"

  if [[ "${LAUNCH_ENABLE_LOG:-0}" != "1" ]]; then
    return 0
  fi

  if [[ -z "$config_file" ]]; then
    echo "Error: LAUNCH_CONFIG_FILE is not set; call load_launch_config first." >&2
    exit 2
  fi

  local log_key
  log_key="$(sglang_log_key_from_config "$script_dir" "$config_file")"

  local log_dir="$script_dir/logs/$log_key"
  if ! mkdir -p "$log_dir"; then
    echo "Error: unable to create SGLang log directory: $log_dir" >&2
    exit 1
  fi

  local timestamp
  timestamp="$(date -u +%Y%m%dT%H%M%SZ)"

  SGLANG_LAUNCH_LOG="$log_dir/${timestamp}_sglang_${script_label}.log"
  export SGLANG_LAUNCH_LOG

  if ! : > "$SGLANG_LAUNCH_LOG"; then
    echo "Error: unable to write SGLang log file: $SGLANG_LAUNCH_LOG" >&2
    exit 1
  fi

  exec > >(tee -a "$SGLANG_LAUNCH_LOG") 2>&1
  echo "SGLang log: $SGLANG_LAUNCH_LOG"
}
