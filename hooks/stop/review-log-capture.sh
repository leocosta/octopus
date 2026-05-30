#!/usr/bin/env bash
# RM-093 — Stop hook that captures review findings from the session transcript
# and appends them to .octopus/review-log/<date>.md for the team mode of
# `continuous-learning` to aggregate across the fleet.
#
# Read-only on the project tree except .octopus/review-log/ (gitignored).
# Deterministic trigger; the semantic aggregation is the team-mode skill,
# reviewed/promoted via /octopus:review-proposals.

set -euo pipefail

# Stop hook receives JSON on stdin with transcript_path.
input=$(cat)
transcript_path=$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null || true)

# Soft-skip when transcript not available (older Claude Code, other agent).
[[ -z "$transcript_path" || ! -f "$transcript_path" ]] && exit 0

# Soft-skip when jq isn't available (degraded environments).
command -v jq >/dev/null 2>&1 || exit 0

project_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
repo_name=$(basename "$project_root")

# --- Extract review findings from the transcript ------------------------
# Review roles (architect/security/mentor) and pr-review emit findings tagged
# BLOCKING: / ADVISORY: / QUESTION:. Pull those lines from assistant messages.
findings=$(jq -r '
  select(.type == "assistant") |
  .message.content[]? |
  select(.type == "text") |
  .text
' "$transcript_path" 2>/dev/null \
  | grep -oiE '(BLOCKING|ADVISORY|QUESTION):[^|]*' \
  | sed 's/[[:space:]]\+/ /g' \
  | head -40 || true)

finding_count=$(printf '%s\n' "$findings" | grep -c . || true)

# Nothing to capture → exit quietly.
[[ "$finding_count" -eq 0 ]] && exit 0

# --- Append structured entries to the review-log ------------------------
log_dir="$project_root/.octopus/review-log"
mkdir -p "$log_dir"
log_file="$log_dir/$(date +%Y-%m-%d).md"
stamp=$(date -Iseconds)

{
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    sev=$(printf '%s' "$line" | grep -oiE '^(BLOCKING|ADVISORY|QUESTION)' | tr '[:lower:]' '[:upper:]')
    topic=$(printf '%s' "$line" | sed -E 's/^(BLOCKING|ADVISORY|QUESTION):[[:space:]]*//I' | cut -c1-160)
    echo "- ${stamp} | repo=${repo_name} | sev=${sev} | topic=\"${topic}\""
  done <<<"$findings"
} >> "$log_file"

# Signal-only: never blocks the Stop.
exit 0
