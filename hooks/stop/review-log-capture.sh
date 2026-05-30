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
# Review roles (architect/security/mentor) and pr-review tag findings with a
# severity — both as inline prose ("BLOCKING: ...") and as Markdown table rows
# ("| BLOCKING | file:line | issue |"). Pull whole lines that carry a severity
# token as a tag (start-of-line, after a pipe, or after whitespace).
findings=$(jq -r '
  select(.type == "assistant") |
  .message.content[]? |
  select(.type == "text") |
  .text
' "$transcript_path" 2>/dev/null \
  | grep -iE '(^|\| *|[[:space:]])(BLOCKING|ADVISORY|QUESTION)([ :|.]|$)' \
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
    sev=$(printf '%s' "$line" | grep -oiE 'BLOCKING|ADVISORY|QUESTION' | head -1 | tr '[:lower:]' '[:upper:]')
    # Topic hint: drop table pipes, the severity token, and file:line locations,
    # then collapse whitespace. Works for both prose and table-row forms.
    topic=$(printf '%s' "$line" \
      | sed -E 's/\|/ /g' \
      | sed -E 's/(BLOCKING|ADVISORY|QUESTION):?//Ig' \
      | sed -E 's#[A-Za-z0-9_./-]+:[0-9]+##g' \
      | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' \
      | cut -c1-160)
    echo "- ${stamp} | repo=${repo_name} | sev=${sev} | topic=\"${topic}\""
  done <<<"$findings"
} >> "$log_file"

# Signal-only: never blocks the Stop.
exit 0
