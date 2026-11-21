#!/usr/bin/env bash
source "${BASH_SOURCE[0]%/*}/../../cli/lib/python.sh" 2>/dev/null || true
# Detect hardcoded secrets before git commit
# Scans the staged files of the repository each `git commit` runs in — after
# `cd`, `git -C <dir>`, `&&` chains — as parsed by cli/lib/hook_git.py (#249).
# Exit 2 = block the tool use

set -euo pipefail

HOOK_GIT="${BASH_SOURCE[0]%/*}/../../cli/lib/hook_git.py"
input=$(cat)

# Fail open — blocking every Bash call on a machine without Python would make
# it unusable — but never silently: a quiet no-op guard is how #245 hid.
if [[ -n "${OCTOPUS_PYTHON_MISSING:-}" ]]; then
  echo "WARNING: detect-secrets disabled: no Python 3 to parse the command." >&2
  exit 0
fi

rc=0
commit_dirs=$(printf '%s' "$input" | python3 "$HOOK_GIT" commit-dirs 2>&1) || rc=$?
if [[ $rc -ne 0 ]]; then
  echo "WARNING: detect-secrets could not check this command: ${commit_dirs:-exit $rc}" >&2
  exit 0
fi
commit_dirs=${commit_dirs//$'\r'/}    # a native Windows Python may still emit CRLF
[[ -z "$commit_dirs" ]] && exit 0

# Secret patterns to detect
patterns=(
  'sk-[a-zA-Z0-9]{20,}'                          # OpenAI API keys
  'ghp_[a-zA-Z0-9]{36}'                           # GitHub personal access tokens
  'gho_[a-zA-Z0-9]{36}'                            # GitHub OAuth tokens
  'github_pat_[a-zA-Z0-9_]{82}'                    # GitHub fine-grained tokens
  'xoxb-[0-9]{10,}-[0-9]{10,}-[a-zA-Z0-9]{24}'   # Slack bot tokens
  'xoxp-[0-9]{10,}-[0-9]{10,}-[a-zA-Z0-9]{24}'   # Slack user tokens
  'AKIA[0-9A-Z]{16}'                               # AWS access key IDs
  'eyJ[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{20,}\.'  # JWT tokens
  'sk_live_[a-zA-Z0-9]{24,}'                       # Stripe live keys
  'rk_live_[a-zA-Z0-9]{24,}'                       # Stripe restricted keys
  'SG\.[a-zA-Z0-9_-]{22}\.[a-zA-Z0-9_-]{43}'     # SendGrid API keys
  'password\s*[:=]\s*["\x27][^"\x27]{8,}'         # Hardcoded passwords
  'secret\s*[:=]\s*["\x27][^"\x27]{8,}'           # Hardcoded secrets
  'api[_-]?key\s*[:=]\s*["\x27][^"\x27]{8,}'     # Hardcoded API keys
)

# The directories come from a command the user has not approved yet, and may be
# an untrusted clone: never let its config run code here (core.fsmonitor, the
# system config), and never run its hooks.
safe_git() {
  GIT_CONFIG_NOSYSTEM=1 git -c core.fsmonitor=false -c core.hooksPath=/dev/null "$@"
}

found=false
# scan_repo <toplevel> — check the files staged in that repository.
scan_repo() {
  local top="$1" staged_files file ext pattern matches
  staged_files=$(safe_git -C "$top" diff --cached --name-only --diff-filter=ACM 2>/dev/null || echo "")
  [[ -z "$staged_files" ]] && return 0
  while IFS= read -r file; do
    [[ -f "$top/$file" ]] || continue

    # Skip binary files and known safe files
    ext="${file##*.}"
    case "$ext" in
      png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|lock|sum) continue ;;
    esac
    case "$file" in
      *.example|*.template|*.md) continue ;;
      *test*|*spec*|*mock*|*fixture*) continue ;;
    esac

    for pattern in "${patterns[@]}"; do
      matches=$(grep -nP "$pattern" "$top/$file" 2>/dev/null || true)
      if [[ -n "$matches" ]]; then
        echo "BLOCKED: Potential secret detected in $file:" >&2
        echo "$matches" | head -3 | sed 's/^/  /' >&2
        found=true
      fi
    done
  done <<< "$staged_files"
}

# One scan per repository, however many commits the command chains
# (a newline-separated list, not an associative array: bash 3.2 on macOS).
scanned=$'\n'
while IFS= read -r dir; do
  # A directory that does not resolve to a repository falls back to the one
  # the command runs in, rather than leaving the commit unscanned.
  top=$(safe_git -C "$dir" rev-parse --show-toplevel 2>/dev/null) \
    || top=$(safe_git rev-parse --show-toplevel 2>/dev/null) || continue
  [[ "$scanned" == *$'\n'"$top"$'\n'* ]] && continue
  scanned+="$top"$'\n'
  scan_repo "$top"
done <<< "$commit_dirs"

if $found; then
  echo "" >&2
  echo "Remove secrets and use environment variables instead." >&2
  echo "If this is a false positive, use OCTOPUS_DISABLED_HOOKS=detect-secrets" >&2
  exit 2
fi

exit 0
