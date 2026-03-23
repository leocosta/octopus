#!/usr/bin/env bash
# Warn about writing to non-standard documentation file locations

set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('file_path',''))" 2>/dev/null || echo "")

# Warn if creating doc files outside docs/ directory
if [[ "$file_path" == *.md && "$file_path" != */docs/* && "$file_path" != */README.md && "$file_path" != */.claude/* && "$file_path" != *CHANGELOG* ]]; then
  basename=$(basename "$file_path")
  # Only warn for new doc-like files, not code-adjacent docs
  case "$basename" in
    CONTRIBUTING.md|LICENSE.md|SECURITY.md) ;;
    *-design.md|*-spec.md|*-plan.md)
      echo "NOTE: Consider placing design docs in docs/ directory." >&2
      ;;
  esac
fi

exit 0
