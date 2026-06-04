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
# After trimming 18 mid-size descriptions: REGISTRY 6461 -> 6137 tok.
# RM-134: registry now includes role descriptions (+~398 tok) -> 6535.
# RM-133 will trim roles; RM-132 will compress the per-stack rule budgets.
MAX_ALWAYS_TOKENS=3000
MAX_REGISTRY_TOKENS=6600
MAX_TOTAL_TOKENS=9500
MAX_DUP_MARKERS=0
# RM-132: stack rules are example-heavy (code blocks are the value) with
# already-terse prose; the only safe automated cut was the csharp override
# boilerplate (3463 -> 3353). python/typescript carry no boilerplate and were
# left intact rather than gut their code examples.
MAX_STACK_CSHARP_TOKENS=3400
MAX_STACK_PYTHON_TOKENS=2600
MAX_STACK_TYPESCRIPT_TOKENS=3950
# RM-135: SKILL.md bodies over the scaffold-skill 250-line guideline (on-demand
# cost per activation). Locks the current 4 (dotnet, launch-release,
# respond-to-review, delegate) and blocks NEW bloat. Lower this as offenders are
# run through `compress-skill` (the anchor-preserving tool built for it);
# dotnet is example-heavy and won't shrink much.
MAX_OVERSIZED_SKILLS=3

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

# --- per-stack rule budgets (RM-132/134) -----------------------------------
mach="$(grep '^ALWAYS_TOKENS=' <<<"$REPORT" | tail -1)"
for lang in CSHARP PYTHON TYPESCRIPT; do
  got=$(grep -oE "STACK_${lang}_TOKENS=[0-9]+" <<<"$mach" | grep -oE '[0-9]+')
  max_var="MAX_STACK_${lang}_TOKENS"; max="${!max_var}"
  check "stack $lang rules <= $max tok (got ${got:-?})" le "$got" "$max"
done
oversized=$(grep -oE 'OVERSIZED_SKILLS=[0-9]+' <<<"$mach" | grep -oE '[0-9]+')
check "oversized skill bodies <= $MAX_OVERSIZED_SKILLS (got ${oversized:-?})" le "$oversized" "$MAX_OVERSIZED_SKILLS"

# --- summary ---------------------------------------------------------------
echo "-----------------------------------------"
echo "context-budget: always=${always:-?} registry=${registry:-?} total=${total:-?} dup=${dup:-?}"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
