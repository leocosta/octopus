#!/usr/bin/env bash
source "${BASH_SOURCE[0]%/*}/../../cli/lib/python.sh" 2>/dev/null || true
# Block git commands that bypass hooks (--no-verify)
# Exit 2 = block the tool use

set -euo pipefail

input=$(cat)
# Claude Code sends the Bash command as tool_input.command (#245).
command=$(printf '%s' "$input" | python3 -c "import sys,json; print((json.load(sys.stdin).get('tool_input') or {}).get('command',''))" 2>/dev/null || echo "")

if [[ "$command" == *"--no-verify"* ]]; then
  echo "BLOCKED: --no-verify flag detected. Do not bypass pre-commit hooks." >&2
  exit 2
fi

exit 0
