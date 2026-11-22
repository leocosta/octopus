#!/usr/bin/env bash
source "${BASH_SOURCE[0]%/*}/../../cli/lib/python.sh" 2>/dev/null || true
# Block git commands that skip hooks: --no-verify (and its prefixes), the
# `git commit -n` short form (alone or in a cluster such as -anm),
# `git -c core.hooksPath=…`, and HUSKY=0 / SKIP=… on a commit.
# The command is tokenized and parsed by cli/lib/hook_git.py (#249), so a
# message that merely mentions a flag is not blocked.
# Exit 2 = block the tool use

set -euo pipefail

HOOK_GIT="${BASH_SOURCE[0]%/*}/../../cli/lib/hook_git.py"
input=$(cat)

# Fail open — blocking every Bash call on a machine without Python would make
# it unusable — but never silently: a quiet no-op guard is how #245 hid.
if [[ -n "${OCTOPUS_PYTHON_MISSING:-}" ]]; then
  echo "WARNING: block-no-verify disabled: no Python 3 to parse the command." >&2
  exit 0
fi

rc=0
reason=$(printf '%s' "$input" | python3 "$HOOK_GIT" no-verify 2>&1) || rc=$?
case $rc in
  0) exit 0 ;;
  2)
    echo "BLOCKED: $reason. Do not bypass pre-commit hooks." >&2
    echo "  If the hook itself is wrong, fix or skip it in its own config; to turn" >&2
    echo "  this guard off for the repo: octopus hooks disable block-no-verify" >&2
    exit 2
    ;;
  *)
    echo "WARNING: block-no-verify could not check this command: ${reason:-exit $rc}" >&2
    exit 0
    ;;
esac
