#!/usr/bin/env bash
# Block git commands that bypass hooks (--no-verify)
# Exit 2 = block the tool use

set -euo pipefail

input=$(cat)
command=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null || echo "")

if [[ "$command" == *"--no-verify"* ]]; then
  echo "BLOCKED: --no-verify flag detected. Do not bypass pre-commit hooks." >&2
  exit 2
fi

exit 0
