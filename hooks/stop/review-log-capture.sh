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

# Soft-skip when jq isn't available (degraded environments).
command -v jq >/dev/null 2>&1 || exit 0

project_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
repo_name=$(basename "$project_root")
log_dir="$project_root/.octopus/review-log"
records_dir="$project_root/.octopus/reviews"

# --- Preferred path: consume structured records (RM-176) ----------------
# A review that ran through `octopus review-session record` already wrote its
# findings with origin, severity and anchored location. Reading that is exact,
# has no 40-finding cap, and fills the src= and file= fields the
# continuous-learning format documents but a transcript grep cannot supply.
consume_records() {
  local marker="$log_dir/.last-record" last="" consumed=0 f id sev src file topic stamp

  [[ -d "$records_dir" ]] || return 1
  [[ -f "$marker" ]] && last="$(cat "$marker" 2>/dev/null)"

  mkdir -p "$log_dir"
  stamp=$(date -Iseconds)

  for f in $(ls -1 "$records_dir"/*.json 2>/dev/null | sort); do
    id="$(basename "$f" .json)"
    # Records are named <UTC timestamp>-<sha>[-n], so a lexical compare is a
    # chronological one.
    [[ -n "$last" && ! "$id" > "$last" ]] && continue

    # Unit separator, not tab: a tab-delimited read collapses empty fields, and a
    # finding with no location has one. `tr` needs the octal form — it does not
    # understand \xHH.
    while IFS=$'\037' read -r sev src file topic; do
      [[ -z "$sev" ]] && continue
      echo "- ${stamp} | repo=${repo_name} | src=${src} | sev=${sev} | topic=\"${topic}\"${file:+ | file=${file}}"
    done < <(jq -r '
      .findings[]
      | [ .severity,
          .origin,
          (if .path then "\(.path):\(.line)" else "" end),
          (.text | gsub("\\[origin:[^\\]]*\\]"; "") | gsub("[A-Za-z0-9_./-]+:[0-9]+"; "") | gsub("^\\s+|\\s+$"; "") | .[0:160])
        ]
      | @tsv
    ' "$f" 2>/dev/null | tr '\t' '\037') >> "$log_dir/$(date +%Y-%m-%d).md"

    last="$id"
    consumed=1
  done

  if [[ $consumed -eq 1 ]]; then
    printf '%s\n' "$last" > "$marker"
    return 0
  fi
  return 1
}

if consume_records; then
  exit 0
fi

# --- Fallback: grep the transcript --------------------------------------
# Kept for reviews that did not record (older runs, other agents, a review
# driven by hand). Lossy by nature: capped at 40, no origin, no location.
transcript_path=$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null || true)

# Soft-skip when transcript not available (older Claude Code, other agent).
[[ -z "$transcript_path" || ! -f "$transcript_path" ]] && exit 0

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
