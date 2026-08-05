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
