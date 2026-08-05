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

# ---------------------------------------------------------------------------
# reflect_apply <base> <ref> <report> <verdicts> [filtered-out]
#
# The asymmetry is the point. Wrongly deleting a claim that called itself
# critical is the one failure this pass could introduce, so a rejected blocker
# is demoted and stays readable; a rejected non-blocker is dropped, because
# triage cost is what the filter exists to remove.
#
# Fail-open throughout: a missing or empty verdicts file, or an id nobody
# mentioned, leaves the finding exactly where it was.
# ---------------------------------------------------------------------------
reflect_apply() {
  local base="$1" ref="$2" report="$3" verdicts="$4" filtered_out="${5:-}"
  local scan decisions row n severity id path lineno v r origin
  local kept=0 demoted=0 dropped=0

  # Truncate once per call, not once per drop — otherwise discards accumulate
  # across repeated or retried runs against the same path.
  [[ -n "$filtered_out" ]] && : > "$filtered_out"

  scan="$(_reflect_scan "$base" "$ref" "$report")"
  decisions="$(mktemp)"

  # Pass 1 — one decision per rejected finding, keyed by its line in the report.
  # Written to a file rather than an associative array: cli/lib/ carries no
  # bash-4 features, and awk reads the map natively in pass 2.
  while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    [[ "$(printf '%s' "$row" | cut -d$'\t' -f2)" == "finding" ]] || continue

    n="$(printf '%s' "$row" | cut -d$'\t' -f1)"
    severity="$(printf '%s' "$row" | cut -d$'\t' -f3)"
    id="$(printf '%s' "$row" | cut -d$'\t' -f4)"
    path="$(printf '%s' "$row" | cut -d$'\t' -f5)"
    lineno="$(printf '%s' "$row" | cut -d$'\t' -f6)"

    v=""; r=""
    if [[ -f "$verdicts" ]]; then
      v="$(awk -F'\t' -v w="$id" '$1 == w { print $2; exit }' "$verdicts")"
      r="$(awk -F'\t' -v w="$id" '$1 == w { print $3; exit }' "$verdicts")"
    fi

    # Anything not explicitly rejected is kept — a missing verdicts file, an
    # empty one, and an id nobody mentioned all land here.
    if [[ "$v" != "reject" ]]; then
      kept=$((kept + 1))
      continue
    fi
    r="${r:-no reason given}"

    case "$severity" in
      BLOCKING|CRITICAL)
        demoted=$((demoted + 1))
        printf '%s\tdemote\t%s\t%s\n' "$n" "$severity" "$r" >> "$decisions" ;;
      *)
        dropped=$((dropped + 1))
        printf '%s\tdrop\t%s\t%s\n' "$n" "$severity" "$r" >> "$decisions"
        if [[ -n "$filtered_out" ]]; then
          origin="$(sed -n "${n}p" "$report" | sed -n 's/.*\[origin:[[:space:]]*\([^]]*\)\].*/\1/p')"
          printf '%s\t%s\t%s\t%s\t%s\n' "$severity" "$origin" "$path" "$lineno" "$r" >> "$filtered_out"
        fi ;;
    esac
  done <<< "$scan"

  # Pass 2 — rewrite the report: drops vanish, demotions are lifted out and
  # folded back in under ADVISORY, everything else passes through verbatim.
  awk -v dec="$decisions" '
    BEGIN {
      while ((getline d < dec) > 0) {
        split(d, f, "\t")
        act[f[1]] = f[2]; osev[f[1]] = f[3]; why[f[1]] = f[4]
        # Escape backslash then ampersand so severity/reason text can be dropped
        # into a sub() replacement below without either being read as the "&"
        # matched-text idiom or a "\" escape — the reason is free text an LLM
        # wrote, so both are ordinary characters in it.
        gsub(/[\\&]/, "\\\\&", osev[f[1]])
        gsub(/[\\&]/, "\\\\&", why[f[1]])
      }
      close(dec)
    }
    act[FNR] == "drop" { next }
    act[FNR] == "demote" {
      line = $0
      # Anchor on the [origin: x] tag itself, not on "the first ]" — a leading
      # markdown checkbox ("- [ ] [origin: x] ...") or a "[P1]"-style prefix
      # would otherwise steal the insertion point. "&" re-emits the matched tag
      # so the reason lands right after it, where a later task reads it back
      # out of the text.
      sub(/\[origin:[^]]*\]/, "& (was " osev[FNR] "; reflection: " why[FNR] ")", line)
      dem[++nd] = line
      next
    }
    { out[++no] = $0 }
    END {
      for (i = 1; i <= no; i++) {
        print out[i]
        if (nd && !ins && out[i] ~ /^[[:space:]]*ADVISORY([[:space:]]*\(|:|[[:space:]]*$)/) {
          for (j = 1; j <= nd; j++) print dem[j]
          ins = 1
        }
      }
      # No ADVISORY section to fold into — append one. Section order in the
      # report is conventional; nothing downstream reads it.
      if (nd && !ins) {
        print ""
        print "ADVISORY (" nd ")"
        for (j = 1; j <= nd; j++) print dem[j]
      }
    }
  ' "$report" | _reflect_recount

  rm -f "$decisions"
  printf 'OCTOPUS_REFLECT_SUMMARY kept=%d demoted=%d filtered=%d\n' "$kept" "$demoted" "$dropped"
}

# ---------------------------------------------------------------------------
# _reflect_recount
#
# Reads a report on stdin and rewrites every section count from the findings
# actually under it. Counts are recomputed rather than adjusted: a stale
# "BLOCKING (2)" over one finding is exactly the kind of quiet wrongness this
# cluster exists to remove.
#
# Only a line already shaped like a header with its count — "SEV (" — is
# eligible for rewrite. The aggregated report format (commands/codereview.md
# Phase 4) always writes the count that way, and the ADVISORY section this
# module appends is written the same way, so real headers still match; a
# prose line that merely starts with a severity word ("MEDIUM: revisit this
# next quarter") does not, and passes through untouched instead of being
# overwritten with a bogus "(0)".
# ---------------------------------------------------------------------------
_reflect_recount() {
  awk -v sev="$_REFLECT_SEVERITIES" '
    # Buffer everything, counting findings per section, then rewrite the counts.
    {
      lines[NR] = $0
      if ($0 ~ "^[[:space:]]*(" sev ")[[:space:]]*\\(") {
        current = NR
        match($0, "(" sev ")")
        sect[NR] = substr($0, RSTART, RLENGTH)
        count[NR] = 0
      } else if (current && index($0, "[origin:")) {
        count[current]++
      }
    }
    END {
      for (i = 1; i <= NR; i++) {
        if (i in sect) printf "%s (%d)\n", sect[i], count[i]
        else print lines[i]
      }
    }
  '
}
