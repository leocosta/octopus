#!/usr/bin/env bash
# Warn about console.log/print statements added to files

set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('file_path',''))" 2>/dev/null || echo "")

[[ -z "$file_path" || ! -f "$file_path" ]] && exit 0

ext="${file_path##*.}"

case "$ext" in
  ts|tsx|js|jsx)
    if grep -n "console\.log" "$file_path" 2>/dev/null | head -3 | grep -q .; then
      echo "WARNING: console.log detected in $file_path — remove before committing." >&2
    fi
    ;;
  py)
    if grep -n "^\s*print(" "$file_path" 2>/dev/null | head -3 | grep -q .; then
      echo "WARNING: print() detected in $file_path — use logging module instead." >&2
    fi
    ;;
esac

exit 0
