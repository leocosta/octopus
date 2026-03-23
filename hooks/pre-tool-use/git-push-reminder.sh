#!/usr/bin/env bash
# Remind to review changes before git push

set -euo pipefail

input=$(cat)
command=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null || echo "")

if [[ "$command" == *"git push"* ]]; then
  echo "REMINDER: Ensure all changes have been reviewed before pushing." >&2
fi

exit 0
