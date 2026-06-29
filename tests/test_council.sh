#!/usr/bin/env bash
# tests/test_council.sh — council skill (workflow-extras).
# Structural checks only: council is a pure-prompt skill (no deterministic CLI
# helper to fixture), so this mirrors the SKILL.md half of
# tests/test_consigliere_lens.sh.
set -uo pipefail   # not -e: a failing check must not abort the suite

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then echo "PASS: $desc"; PASS=$((PASS + 1))
  else echo "FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

SKILL="$OCTOPUS_DIR/skills/council/SKILL.md"
CMD="$OCTOPUS_DIR/commands/council.md"

# ---------------------------------------------------------------------------
# SKILL.md — frontmatter
# ---------------------------------------------------------------------------
t_frontmatter()  { [[ -f "$SKILL" ]] && head -5 "$SKILL" | grep -q '^name: council$'; }
t_model_tier()   { grep -qE '^model: (sonnet|haiku)$' "$SKILL"; }
t_triggers()     {
  grep -q '^triggers:' "$SKILL" || return 1
  grep -q '"council"' "$SKILL" || return 1
  grep -q 'pressure-test' "$SKILL" || return 1
  grep -q 'which option' "$SKILL"
}

check "skill: valid frontmatter"                 t_frontmatter
check "skill: declares a model tier"             t_model_tier
check "skill: triggers carry strong keywords"    t_triggers

# ---------------------------------------------------------------------------
# SKILL.md — the four-phase protocol + fixed chairman structure
# ---------------------------------------------------------------------------
t_phase_frame()    { grep -qi 'Frame' "$SKILL"; }
t_phase_convene()  { grep -qi 'Convene' "$SKILL"; }
t_phase_review()   { grep -qi 'peer-review' "$SKILL"; }
t_phase_chairman() { grep -qi 'Chairman' "$SKILL"; }
t_verdict_struct() {
  grep -q 'Where the Council Agrees' "$SKILL" \
    && grep -q 'Where the Council Clashes' "$SKILL" \
    && grep -q 'Blind Spots the Council Caught' "$SKILL" \
    && grep -q 'The Recommendation' "$SKILL" \
    && grep -q 'The One Thing to Do First' "$SKILL"
}

check "skill: phase 1 — frame"                   t_phase_frame
check "skill: phase 2 — convene"                 t_phase_convene
check "skill: phase 3 — peer-review"             t_phase_review
check "skill: phase 4 — chairman"                t_phase_chairman
check "skill: chairman fixed verdict structure"  t_verdict_struct

# ---------------------------------------------------------------------------
# SKILL.md — the design invariants the plan locked in
# ---------------------------------------------------------------------------
t_anonymize()   { grep -qi 'anonymi' "$SKILL" && grep -q 'Response A' "$SKILL"; }
t_parallel()    { grep -q 'dispatching-parallel-agents' "$SKILL" && grep -qi 'sequential' "$SKILL"; }
t_ephemeral()   { grep -qi 'ephemeral' "$SKILL" && grep -qi 'not roles' "$SKILL"; }
t_read_only()   { grep -qiE 'read-only|writes nothing|no files' "$SKILL"; }

check "skill: anonymous A–E peer-review rule"    t_anonymize
check "skill: parallel dispatch + degradation"   t_parallel
check "skill: ephemeral lenses, not roles"       t_ephemeral
check "skill: read-only / no files by default"   t_read_only

# ---------------------------------------------------------------------------
# Command — thin delegator
# ---------------------------------------------------------------------------
t_cmd_refs_skill() { [[ -f "$CMD" ]] && grep -qE 'skills/council|`council` skill' "$CMD"; }
t_cmd_thin()       { [[ -f "$CMD" ]] && [[ "$(wc -l < "$CMD")" -le 60 ]]; }

check "command: thin delegator references skill" t_cmd_refs_skill
check "command: thin (<= 60 lines)"              t_cmd_thin

# ---------------------------------------------------------------------------
# Wiring — bundle + doc pages
# ---------------------------------------------------------------------------
t_bundle()     { grep -rqE '^ *- council( |$)' "$OCTOPUS_DIR/bundles"; }
t_docs_skill() { [[ -f "$OCTOPUS_DIR/docs/site/skills/council.mdx" ]] && [[ -f "$OCTOPUS_DIR/docs/site/pt-br/skills/council.mdx" ]]; }
t_docs_cmd()   { [[ -f "$OCTOPUS_DIR/docs/site/commands/council.mdx" ]] && [[ -f "$OCTOPUS_DIR/docs/site/pt-br/commands/council.mdx" ]]; }

check "bundle: registered in workflow-extras"    t_bundle
check "docs: EN + pt-br skill pages exist"        t_docs_skill
check "docs: EN + pt-br command pages exist"       t_docs_cmd

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
