#!/usr/bin/env bash
# cli/lib/reflect-payload.sh — Select, present, and adjudicate review findings.
#
# RM-171. A review's findings are written by models and nothing stands between
# them and the report; a false BLOCKING stops real work, and noise is where
# triage gets abandoned. This library is the deterministic half of the filter:
# it decides what is adjudicable, shows the adjudicator only the anchored code,
# and applies the verdicts. The judgement itself is the one model call in
# between — see cli/lib/review-reflect.sh.
#
# Public API:
#   reflect_origin_eligible <origin>                 → exit 0 if model-authored
#   reflect_code_window <ref> <path> <line> [radius] → numbered slice, cited line marked
#   reflect_prepare <base> <ref> <report>            → payload; exit 1 if nothing eligible
#   reflect_apply <base> <ref> <report> <verdicts> [filtered-out] → rewritten report
#
# Sourced by cli/lib/review-reflect.sh and from tests. No side effects on source.

REFLECT_PAYLOAD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./anchor-verify.sh
source "$REFLECT_PAYLOAD_LIB_DIR/anchor-verify.sh"

REFLECT_WINDOW_RADIUS="${REFLECT_WINDOW_RADIUS:-15}"
REFLECT_MODEL="${REFLECT_MODEL:-sonnet}"

# ---------------------------------------------------------------------------
# reflect_origin_eligible <origin>
#
# Roles and audit-* skills reason; `fallback` (Phase 3) and `definition-of-done`
# (Phase 3.5) are greps and per-item verdicts, true by construction. Paying a
# model to adjudicate a TODO match is waste.
# ---------------------------------------------------------------------------
reflect_origin_eligible() {
  case "${1:-}" in
    architect|dba|security) return 0 ;;
    audit-*) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# reflect_code_window <ref> <path> <line> [radius]
#
# The cited line plus context, line-numbered, cited line prefixed '>'. This is
# what bounds the cost of the pass: the adjudicator sees N windows, never the
# whole diff.
# ---------------------------------------------------------------------------
reflect_code_window() {
  local ref="$1" path="$2" line="$3" radius="${4:-$REFLECT_WINDOW_RADIUS}"
  local start=$(( line - radius )) end=$(( line + radius ))
  (( start < 1 )) && start=1

  git show "${ref}:${path}" 2>/dev/null | awk -v s="$start" -v e="$end" -v c="$line" '
    NR < s { next }
    NR > e { exit }
    { printf "%s %5d | %s\n", (NR == c ? ">" : " "), NR, $0 }
  '
}

# Same severity set as _REVIEW_SEVERITIES in review-record.sh. Second occurrence:
# a third should move it to a shared lib rather than add another copy.
_REFLECT_SEVERITIES='BLOCKING|ADVISORY|QUESTION|CRITICAL|HIGH|MEDIUM|LOW'

# ---------------------------------------------------------------------------
# _reflect_scan <base> <ref> <report>
#
# One walk of the report, shared by prepare and apply. Eligibility is decided
# here and nowhere else: a finding is adjudicable iff its origin is
# model-authored AND its RM-170 anchor resolves to real code. no-anchor is
# excluded — there is nothing to confront, and judging prose against prose is
# what this pass exists to avoid.
#
# Emits: lineno<TAB>kind<TAB>severity<TAB>id<TAB>path<TAB>cited-line
# ---------------------------------------------------------------------------
_reflect_scan() {
  local base="$1" ref="$2" report="$3"
  local n=0 id=0 severity="" line origin anchor path lineno verdict

  while IFS= read -r line; do
    n=$((n + 1))

    if [[ "$line" =~ ^[[:space:]]*($_REFLECT_SEVERITIES)([[:space:]]*\(|:|[[:space:]]*$) ]]; then
      severity="${BASH_REMATCH[1]}"
      printf '%d\theader\t%s\t\t\t\n' "$n" "$severity"
      continue
    fi

    [[ "$line" == *"[origin:"* ]] || continue

    origin="$(printf '%s' "$line" | sed -n 's/.*\[origin:[[:space:]]*\([^]]*\)\].*/\1/p' | sed 's/[[:space:]]*$//')"

    anchor="$(anchor_extract "$line")"
    if [[ -n "$anchor" ]]; then
      path="${anchor%%$'\t'*}"
      lineno="${anchor##*$'\t'}"
      verdict="$(anchor_verify "$base" "$ref" "$path" "$lineno")"
    else
      path=""; lineno=""; verdict="no-anchor"
    fi

    if reflect_origin_eligible "$origin" \
      && [[ "$verdict" == "anchored" || "$verdict" == "not-in-diff" ]]; then
      id=$((id + 1))
      printf '%d\tfinding\t%s\t%d\t%s\t%s\n' "$n" "${severity:-UNKNOWN}" "$id" "$path" "$lineno"
    else
      printf '%d\tskip\t%s\t\t\t\n' "$n" "${severity:-UNKNOWN}"
    fi
  done < "$report"
}

# ---------------------------------------------------------------------------
# reflect_prepare <base> <ref> <report>
#
# The adjudicator's whole input: each eligible finding and the window of code it
# points at. The origin travels inside the finding's own text, so it is not
# repeated as a field.
#
# Exit 1 means nothing was eligible — the caller skips the model call, the same
# "don't spawn" saving audit-scope makes for audits (RM-172).
# ---------------------------------------------------------------------------
reflect_prepare() {
  local base="$1" ref="$2" report="$3"
  local scan row n severity id path lineno text

  scan="$(_reflect_scan "$base" "$ref" "$report")"
  printf '%s\n' "$scan" | grep -q $'\tfinding\t' || return 1

  printf 'OCTOPUS_REFLECT_MODEL %s\n' "$REFLECT_MODEL"

  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    [[ "$(printf '%s' "$row" | cut -d$'\t' -f2)" == "finding" ]] || continue

    n="$(printf '%s' "$row" | cut -d$'\t' -f1)"
    severity="$(printf '%s' "$row" | cut -d$'\t' -f3)"
    id="$(printf '%s' "$row" | cut -d$'\t' -f4)"
    path="$(printf '%s' "$row" | cut -d$'\t' -f5)"
    lineno="$(printf '%s' "$row" | cut -d$'\t' -f6)"
    text="$(sed -n "${n}p" "$report" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

    printf '\n--- FINDING %s ---\n' "$id"
    printf 'severity: %s\n' "$severity"
    printf 'text: %s\n' "$text"
    printf 'code: %s (cited line %s, marked >)\n' "$path" "$lineno"
    reflect_code_window "$ref" "$path" "$lineno"
  done <<< "$scan"

  return 0
}
