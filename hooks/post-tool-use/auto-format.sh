#!/usr/bin/env bash
# Auto-format files after Write/Edit based on file extension.
#
# Failures are reported to stderr but never fail the hook, so a broken
# formatter run cannot block Claude's tool call.

set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('file_path',''))" 2>/dev/null || echo "")

[[ -z "$file_path" || ! -f "$file_path" ]] && exit 0

has() { command -v "$1" &>/dev/null; }

run_formatter() {
  local tool="$1"; shift
  local out rc=0
  out=$("$@" 2>&1) || rc=$?
  if [[ $rc -ne 0 ]]; then
    local first
    first=$(printf '%s\n' "$out" | awk 'NF{print;exit}')
    echo "[auto-format] $tool failed on $file_path (exit $rc): ${first:-<no output>}" >&2
  fi
  return 0
}

ext="${file_path##*.}"

case "$ext" in
  ts|tsx|js|jsx|mjs|cjs|json|jsonc)
    if has biome; then
      run_formatter biome biome check --write "$file_path"
    elif has eslint || has prettier; then
      has eslint   && run_formatter eslint   eslint --fix "$file_path"
      has prettier && run_formatter prettier prettier --write "$file_path"
    elif has npx; then
      run_formatter prettier npx --yes prettier --write "$file_path"
    fi
    ;;
  cs|csx)
    if has csharpier; then
      run_formatter csharpier csharpier format "$file_path"
    elif has dotnet; then
      run_formatter "dotnet format" dotnet format --include "$file_path"
    fi
    ;;
  py)
    if has ruff; then
      run_formatter ruff ruff format "$file_path"
    elif has black; then
      run_formatter black black "$file_path"
    fi
    ;;
esac
