#!/usr/bin/env bash
# tests/test_context_budget.sh
# RM-131 — the context-budget ratchet. Runs scripts/context-budget.sh and
# asserts the always-loaded baseline, registry listing, and core<->rules
# duplication stay at or below a ceiling. The ceilings ratchet DOWN as the
# Cluster 23 RMs land — never raise one to make a regression pass; lower it
# when an RM cuts tokens, in the same commit. Grep/exit-code assertions, per
# project convention.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUDGET="$SCRIPT_DIR/scripts/context-budget.sh"

# --- ceilings (ratchet down as Cluster 23 lands) ---------------------------
# Baseline 2026-06-03 (pre-refactor): ALWAYS=8407 REGISTRY=2209 TOTAL=10616 DUP=3.
# After RM-117 (dedup core<->rules): ALWAYS=7989 DUP=0.
# After RM-119 (core reference on-demand): ALWAYS=5418 TOTAL=7627.
# After RM-118 (exceptions.md on-demand): ALWAYS=3089.
# After RM-121 (compress rules/common): ALWAYS=2905.
# RM-128 corrected the registry counter to sum full multi-line descriptions:
# the true registry was 8013 tok (not the 2209 the first-line counter showed).
# After trimming 24 verbose descriptions: REGISTRY 8013 -> 6461 tok.
MAX_ALWAYS_TOKENS=3000
MAX_REGISTRY_TOKENS=6500
MAX_TOTAL_TOKENS=9450
MAX_DUP_MARKERS=0

PASS=0; FAIL=0
check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then echo "PASS: $desc"; PASS=$((PASS + 1))
  else echo "FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

# --- the harness exists and runs -------------------------------------------
check "budget script exists" test -f "$BUDGET"
check "budget script is executable" test -x "$BUDGET"

REPORT="$("$BUDGET" "$SCRIPT_DIR" 2>/dev/null || true)"
check "report emits the machine-readable summary" grep -q 'TOTAL_TOKENS=' <<<"$REPORT"

# --- parse the summary line ------------------------------------------------
summary="$(grep -oE 'ALWAYS_TOKENS=[0-9]+ REGISTRY_TOKENS=[0-9]+ TOTAL_TOKENS=[0-9]+ DUP_MARKERS=[0-9]+' <<<"$REPORT" | tail -1)"
always=$(sed -E 's/.*ALWAYS_TOKENS=([0-9]+).*/\1/' <<<"$summary")
registry=$(sed -E 's/.*REGISTRY_TOKENS=([0-9]+).*/\1/' <<<"$summary")
total=$(sed -E 's/.*TOTAL_TOKENS=([0-9]+).*/\1/' <<<"$summary")
dup=$(sed -E 's/.*DUP_MARKERS=([0-9]+).*/\1/' <<<"$summary")

# --- the ratchet -----------------------------------------------------------
le() { [[ "${1:-999999}" -le "$2" ]]; }
check "always-loaded baseline <= $MAX_ALWAYS_TOKENS tok (got ${always:-?})" le "$always" "$MAX_ALWAYS_TOKENS"
check "registry listing <= $MAX_REGISTRY_TOKENS tok (got ${registry:-?})"   le "$registry" "$MAX_REGISTRY_TOKENS"
check "total per session <= $MAX_TOTAL_TOKENS tok (got ${total:-?})"        le "$total" "$MAX_TOTAL_TOKENS"
check "core<->rules dup markers <= $MAX_DUP_MARKERS (got ${dup:-?})"        le "$dup" "$MAX_DUP_MARKERS"

# --- summary ---------------------------------------------------------------
echo "-----------------------------------------"
echo "context-budget: always=${always:-?} registry=${registry:-?} total=${total:-?} dup=${dup:-?}"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
