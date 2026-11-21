#!/usr/bin/env bash
source "${BASH_SOURCE[0]%/*}/../../cli/lib/python.sh" 2>/dev/null || true
# Remind to review changes before git push (any `git push`, however spelled:
# `git -C repo push`, after `&&`, …). Parsed by cli/lib/hook_git.py (#249).

set -euo pipefail

HOOK_GIT="${BASH_SOURCE[0]%/*}/../../cli/lib/hook_git.py"
input=$(cat)
[[ -n "${OCTOPUS_PYTHON_MISSING:-}" ]] && exit 0   # a reminder: nothing to guard

if printf '%s' "$input" | python3 "$HOOK_GIT" has push >/dev/null 2>&1; then
  echo "REMINDER: Ensure all changes have been reviewed before pushing." >&2
fi

exit 0
