#!/usr/bin/env bash
# Final check for console.log/print statements in modified files

set -euo pipefail

# Get files modified in this session (unstaged + staged)
modified_files=$(git diff --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null)

[[ -z "$modified_files" ]] && exit 0

found=false
while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  ext="${file##*.}"
  case "$ext" in
    ts|tsx|js|jsx)
      if grep -l "console\.log" "$file" 2>/dev/null | grep -q .; then
        echo "WARNING: console.log found in modified file: $file" >&2
        found=true
      fi
      ;;
    py)
      if grep -l "^\s*print(" "$file" 2>/dev/null | grep -q .; then
        echo "WARNING: print() found in modified file: $file" >&2
        found=true
      fi
      ;;
  esac
done <<< "$modified_files"

if $found; then
  echo "Remove debug statements before committing." >&2
fi

exit 0
