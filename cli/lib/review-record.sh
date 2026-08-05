#!/usr/bin/env bash
# cli/lib/review-record.sh — Turn an aggregated review report into a structured record.
#
# RM-176. The report a review produces is prose. `review-log-capture.sh` (RM-093)
# recovers some of it by grepping the transcript afterwards, which truncates at 40
# findings and keeps no origin, ref, anchor or verdict. This parses the report at
# the source instead, while the run still knows its own context.
#
# Public API:
#   review_record_parse <base> <ref> [report-file]   → one TSV row per finding:
#                                                      severity<TAB>origin<TAB>path<TAB>line<TAB>anchor<TAB>text<TAB>reflection
#   review_record_json <base> <ref> <report-file> [audits-file] [filtered-file] → the full record
#   review_record_dir                                → the records directory
#
# Sourced by cli/lib/review-session.sh and from tests. No side effects on source.

REVIEW_RECORD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./anchor-verify.sh
source "$REVIEW_RECORD_LIB_DIR/anchor-verify.sh"

REVIEW_RECORD_ROOT="${REVIEW_RECORD_ROOT:-.octopus/reviews}"

review_record_dir() { printf '%s' "$REVIEW_RECORD_ROOT"; }

# Severity tokens: the roles' scale and the audit skills' scale both appear in an
# aggregated report (codereview Phase 4 merges them without flattening).
_REVIEW_SEVERITIES='BLOCKING|ADVISORY|QUESTION|CRITICAL|HIGH|MEDIUM|LOW'

# ---------------------------------------------------------------------------
# _review_record_escape <string> — minimal JSON string escaping, no jq needed on
# the write path so a record is still produced in degraded environments.
# ---------------------------------------------------------------------------
_review_record_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//	/\\t}"
  s="${s//$'\r'/}"
  printf '%s' "$s"
}

# ---------------------------------------------------------------------------
# review_record_parse <base> <ref> [report-file]
#
# A section header sets the severity in force ("BLOCKING (2)"); a line carrying
# [origin: x] is a finding. Anchors are resolved through RM-170, so a record can
# never claim a location the diff does not support.
# ---------------------------------------------------------------------------
review_record_parse() {
  local base="$1" ref="$2" report="${3:-}"
  local severity="" line cited origin anchor path lineno text reflection

  _review_record_stream() {
    if [[ -n "$report" ]]; then cat "$report"; else cat; fi
  }

  while IFS= read -r line; do
    # Section header — sets the severity for the findings that follow.
    if [[ "$line" =~ ^[[:space:]]*($_REVIEW_SEVERITIES)([[:space:]]*\(|:|[[:space:]]*$) ]]; then
      severity="${BASH_REMATCH[1]}"
      continue
    fi

    # Findings carry an origin tag.
    [[ "$line" == *"[origin:"* ]] || continue

    origin="$(printf '%s' "$line" | sed -n 's/.*\[origin:[[:space:]]*\([^]]*\)\].*/\1/p' | sed 's/[[:space:]]*$//')"
    [[ -n "$origin" ]] || origin="unknown"

    # RM-171: a demoted finding carries "(was <SEV>; reflection: <reason>)"
    # spliced in right after its [origin: x] tag — ahead of its own citation.
    # The reason is free text, and rejecting a claim by pointing at the real
    # code ("the index already exists at src/app.ts:30") is the natural way to
    # write one, so the note must come off before anchor_extract, which takes
    # the *first* citation on the line. Without this the record — the durable
    # artifact everything downstream reads — cites the adjudicator's location
    # instead of the finding's, and the RM-170 verdict is computed against the
    # wrong file. Kept in the finding's `text` below: only the citation read is
    # note-blind. The same strip is applied in _reflect_scan
    # (cli/lib/reflect-payload.sh); a third reader should share one helper.
    cited="$(printf '%s' "$line" | sed 's/[[:space:]]*(was [A-Z][A-Z]*; reflection:[^)]*)//')"

    anchor="$(anchor_extract "$cited")"
    if [[ -n "$anchor" ]]; then
      path="${anchor%%$'\t'*}"
      lineno="${anchor##*$'\t'}"
      verdict="$(anchor_verify "$base" "$ref" "$path" "$lineno")"
    else
      path=""; lineno=""; verdict="no-anchor"
    fi

    text="$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    # A literal tab in a finding's text would otherwise shift every column
    # after it once it lands in this row (same hazard the awk reader below
    # is already guarding against for empty fields).
    text="${text//$'\t'/ }"

    # RM-171: a demoted finding carries its own reason in its text — apply wrote
    # it there, so the record needs no side channel to recover it. Anchored on
    # the full "(was <SEV>; reflection: " prefix apply actually writes, not on
    # a bare "reflection:" — a finding whose own prose happens to contain that
    # word must not be misread as a demotion.
    reflection="$(printf '%s' "$line" | sed -n 's/.*(was [A-Z][A-Z]*; reflection:[[:space:]]*\([^)]*\)).*/\1/p')"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "${severity:-UNKNOWN}" "$origin" "$path" "$lineno" "$verdict" "$text" "$reflection"
  done < <(_review_record_stream)
}

# ---------------------------------------------------------------------------
# review_record_json <base> <ref> <report-file> [audits-file] [filtered-file]
#
# audits-file, when given, is "<audit-name> <outcome>" per line, where outcome is
# skip | cached | scoped — the audit-scope resolution from RM-172. Recording it is
# what lets a later run know what was actually covered.
#
# filtered-file, when given, is reflect_apply's filtered.tsv (RM-171):
# severity<TAB>origin<TAB>path<TAB>line<TAB>reason, one dropped finding per line.
# ---------------------------------------------------------------------------
review_record_json() {
  local base="$1" ref="$2" report="$3" audits="${4:-}" filtered="${5:-}"
  local created repo rows first

  created="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  repo="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"
  rows="$(review_record_parse "$base" "$ref" "$report")"

  printf '{\n'
  printf '  "created_at": "%s",\n' "$created"
  printf '  "repo": "%s",\n' "$(_review_record_escape "$repo")"
  printf '  "base": "%s",\n' "$(_review_record_escape "$base")"
  printf '  "ref": "%s",\n' "$(_review_record_escape "$ref")"
  printf '  "ref_sha": "%s",\n' "$(git rev-parse "$ref" 2>/dev/null || echo unknown)"

  # Audit resolutions — the skip/cached/scoped verdicts from audit-scope.
  printf '  "audits": ['
  first=1
  if [[ -n "$audits" && -f "$audits" ]]; then
    while read -r name outcome _; do
      [[ -z "$name" ]] && continue
      [[ $first -eq 1 ]] || printf ','
      printf '\n    {"name": "%s", "outcome": "%s"}' \
        "$(_review_record_escape "$name")" "$(_review_record_escape "$outcome")"
      first=0
    done < "$audits"
    [[ $first -eq 0 ]] && printf '\n  '
  fi
  printf '],\n'

  # Findings.
  #
  # Read with awk, not `IFS=$'\t' read`: tab is IFS-whitespace, so bash collapses
  # consecutive tabs and a finding with no citation (two empty fields in a row)
  # would shift every column after it. Same hazard applies to $7 (reflection):
  # it is empty for every untouched finding.
  printf '  "findings": ['
  if [[ -n "$rows" ]]; then
    printf '%s\n' "$rows" | awk -F'\t' '
      function esc(s) {
        gsub(/\\/, "\\\\", s)
        gsub(/"/, "\\\"", s)
        gsub(/\r/, "", s)
        return s
      }
      NF == 0 { next }
      {
        printf "%s\n    {\"severity\": \"%s\", \"origin\": \"%s\", \"path\": %s, \"line\": %s, \"anchor\": \"%s\", \"text\": \"%s\", \"reflection\": %s}",
          (n++ ? "," : ""),
          esc($1), esc($2),
          ($3 == "" ? "null" : "\"" esc($3) "\""),
          ($4 == "" ? "null" : $4),
          esc($5), esc($6),
          ($7 == "" ? "null" : "\"" esc($7) "\"")
      }
      END { if (n) printf "\n  " }
    '
  fi
  printf ']'

  # Filtered — the non-blockers reflect_apply dropped entirely (RM-171). A
  # record written before this change has no such array; callers must treat
  # its absence as empty rather than an error (see review-session.sh's
  # `.filtered // []`).
  printf ',\n  "filtered": ['
  if [[ -n "$filtered" && -f "$filtered" ]]; then
    awk -F'\t' '
      function esc(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); gsub(/\r/, "", s); return s }
      NF == 0 { next }
      {
        printf "%s\n    {\"severity\": \"%s\", \"origin\": \"%s\", \"path\": %s, \"line\": %s, \"reason\": \"%s\"}",
          (n++ ? "," : ""),
          esc($1), esc($2),
          ($3 == "" ? "null" : "\"" esc($3) "\""),
          ($4 == "" ? "null" : $4),
          esc($5)
      }
      END { if (n) printf "\n  " }
    ' "$filtered"
  fi
  printf ']\n'
  printf '}\n'
}
