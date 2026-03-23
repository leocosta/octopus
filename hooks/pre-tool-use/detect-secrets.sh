#!/usr/bin/env bash
# Detect hardcoded secrets before git commit
# Scans staged files for common secret patterns
# Exit 2 = block the tool use

set -euo pipefail

input=$(cat)
command=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null || echo "")

# Only trigger on git commit
[[ "$command" != *"git commit"* ]] && exit 0

# Get staged files
staged_files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || echo "")
[[ -z "$staged_files" ]] && exit 0

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

found=false
while IFS= read -r file; do
  [[ -f "$file" ]] || continue

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
    matches=$(grep -nP "$pattern" "$file" 2>/dev/null || true)
    if [[ -n "$matches" ]]; then
      echo "BLOCKED: Potential secret detected in $file:" >&2
      echo "$matches" | head -3 | sed 's/^/  /' >&2
      found=true
    fi
  done
done <<< "$staged_files"

if $found; then
  echo "" >&2
  echo "Remove secrets and use environment variables instead." >&2
  echo "If this is a false positive, use OCTOPUS_DISABLED_HOOKS=detect-secrets" >&2
  exit 2
fi

exit 0
