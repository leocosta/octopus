#!/usr/bin/env bash
source "${BASH_SOURCE[0]%/*}/../../cli/lib/python.sh" 2>/dev/null || true
# Remind to review changes before git push

set -euo pipefail

input=$(cat)
# Claude Code sends the Bash command as tool_input.command (#245).
command=$(printf '%s' "$input" | python3 -c "import sys,json; print((json.load(sys.stdin).get('tool_input') or {}).get('command',''))" 2>/dev/null || echo "")

if [[ "$command" == *"git push"* ]]; then
  echo "REMINDER: Ensure all changes have been reviewed before pushing." >&2
fi

exit 0
