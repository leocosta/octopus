#!/usr/bin/env bash
# Auto-format files after edit based on file extension
# Detects available formatters and runs the appropriate one

set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('file_path',''))" 2>/dev/null || echo "")

[[ -z "$file_path" || ! -f "$file_path" ]] && exit 0

ext="${file_path##*.}"

case "$ext" in
  ts|tsx|js|jsx|json)
    if command -v biome &>/dev/null; then
      biome format --write "$file_path" 2>/dev/null || true
    elif command -v prettier &>/dev/null; then
      prettier --write "$file_path" 2>/dev/null || true
    elif command -v npx &>/dev/null; then
      npx --yes prettier --write "$file_path" 2>/dev/null || true
    fi
    ;;
  cs)
    if command -v dotnet &>/dev/null; then
      dotnet format --include "$file_path" 2>/dev/null || true
    fi
    ;;
  py)
    if command -v ruff &>/dev/null; then
      ruff format "$file_path" 2>/dev/null || true
    elif command -v black &>/dev/null; then
      black "$file_path" 2>/dev/null || true
    fi
    ;;
esac

exit 0
