#!/usr/bin/env bash
set -euo pipefail

# Run upgrade scripts found next to this script, independent of current directory.
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

scripts=(
  "upgrade_claude.sh"
  "upgrade_ccr.sh"
  "upgrade_codex.sh"
  "upgrade_cursor.sh"
  "upgrade_gemini.sh"
  "upgrade_opencode.sh"
)

for script in "${scripts[@]}"; do
  script_path="$script_dir/$script"
  if [[ -x "$script_path" ]]; then
    echo "==> Running $script_path"
    "$script_path"
  elif [[ -f "$script_path" ]]; then
    echo "==> Running $script_path with bash"
    bash "$script_path"
  else
    echo "Skipping $script (not found in $script_dir)" >&2
  fi
done
