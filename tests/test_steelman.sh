#!/usr/bin/env bash
# tests/test_steelman.sh — steelman skill (workflow-extras).
# Structural checks only: steelman is a pure-prompt skill (no deterministic CLI
# helper to fixture), so this mirrors tests/test_council.sh.
set -uo pipefail   # not -e: a failing check must not abort the suite

OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then echo "PASS: $desc"; PASS=$((PASS + 1))
  else echo "FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

SKILL="$OCTOPUS_DIR/skills/steelman/SKILL.md"
CMD="$OCTOPUS_DIR/commands/steelman.md"
ADR="$OCTOPUS_DIR/skills/doc-adr/SKILL.md"

# ---------------------------------------------------------------------------
# SKILL.md — frontmatter
# ---------------------------------------------------------------------------
t_frontmatter() { [[ -f "$SKILL" ]] && head -5 "$SKILL" | grep -q '^name: steelman$'; }
t_model_tier()  { grep -qE '^model: (sonnet|haiku)$' "$SKILL"; }
t_triggers()    {
  grep -q '^triggers:' "$SKILL" || return 1
  grep -q '"steel man"' "$SKILL" || return 1
  grep -q 'best case against' "$SKILL" || return 1
  grep -q 'argue the other side' "$SKILL"
}
# The name is jargon; the description has to carry the meaning on its own.
t_description() { grep -qiE '^ *description:|strongest' "$SKILL"; }

check "skill: valid frontmatter"                 t_frontmatter
check "skill: declares a model tier"             t_model_tier
check "skill: triggers carry the jargon load"    t_triggers
check "skill: description states the capability" t_description

# ---------------------------------------------------------------------------
# SKILL.md — the six-step protocol
# ---------------------------------------------------------------------------
t_step_position()  { grep -qiE 'real position|position being defended' "$SKILL"; }
t_step_opposition(){ grep -qi 'strawman' "$SKILL" && grep -qiE 'genuine opposition|strong contrary' "$SKILL"; }
t_step_maximal()   { grep -qi 'strongest' "$SKILL" && grep -qiE 'competent critic|best evidence' "$SKILL"; }
t_step_bites()     { grep -qiE 'bites|lethal' "$SKILL" && grep -qi 'rhetoric' "$SKILL"; }
t_step_survival()  { grep -qiE 'survival test|would you have to believe' "$SKILL"; }
t_step_buckets()   { grep -qiE 'demands an answer' "$SKILL" && grep -qi 'concede' "$SKILL"; }

check "skill: step 1 — extract the real position" t_step_position
check "skill: step 2 — genuine opposition"        t_step_opposition
check "skill: step 3 — build the maximal case"    t_step_maximal
check "skill: step 4 — what bites vs rhetoric"    t_step_bites
check "skill: step 5 — survival test"             t_step_survival
check "skill: step 6 — two buckets"               t_step_buckets

# ---------------------------------------------------------------------------
# SKILL.md — the invariant that separates this from the Contrarian
# ---------------------------------------------------------------------------
# Steel man CONSTRUCTS the opposing case; it does not attack. Losing that
# distinction collapses the skill into council's Contrarian lens.
t_construct_not_attack() {
  grep -qiE 'not attack|rather than attack|does not attack' "$SKILL" \
    && grep -qi 'contrarian' "$SKILL"
}
# Sharpening, not capitulating.
t_not_capitulation() { grep -qiE 'capitulat|concede the whole|abandon(ing)? the thesis' "$SKILL"; }
t_anti_patterns()    { grep -q '^## Anti-Patterns' "$SKILL"; }
t_length()           { [[ -f "$SKILL" ]] && [[ "$(wc -l < "$SKILL")" -le 250 ]]; }

check "skill: constructs, not attacks (vs Contrarian)" t_construct_not_attack
check "skill: sharpen, not capitulate"                 t_not_capitulation
check "skill: names its anti-patterns"                 t_anti_patterns
check "skill: within the 250-line cap"                 t_length

# ---------------------------------------------------------------------------
# Command — thin delegator
# ---------------------------------------------------------------------------
t_cmd_refs_skill() { [[ -f "$CMD" ]] && grep -qE 'skills/steelman|`steelman` skill' "$CMD"; }
t_cmd_thin()       { [[ -f "$CMD" ]] && [[ "$(wc -l < "$CMD")" -le 60 ]]; }

check "command: thin delegator references skill" t_cmd_refs_skill
check "command: thin (<= 60 lines)"              t_cmd_thin

# ---------------------------------------------------------------------------
# Call site — doc-adr is the one integration (respond-to-review was excluded)
# ---------------------------------------------------------------------------
t_adr_call_site() { grep -qi 'steelman\|steel man' "$ADR"; }
t_adr_gated()     { grep -qiE 'steel-?man' "$ADR" && grep -qi 'alternative' "$ADR"; }

check "doc-adr: invokes steelman"                t_adr_call_site
check "doc-adr: scoped to alternatives"          t_adr_gated

# ---------------------------------------------------------------------------
# Wiring — bundle + doc pages
# ---------------------------------------------------------------------------
t_bundle()     { grep -rqE '^ *- steelman( |$)' "$OCTOPUS_DIR/bundles"; }
t_docs_skill() { [[ -f "$OCTOPUS_DIR/docs/site/skills/steelman.mdx" ]] && [[ -f "$OCTOPUS_DIR/docs/site/pt-br/skills/steelman.mdx" ]]; }
t_docs_cmd()   { [[ -f "$OCTOPUS_DIR/docs/site/commands/steelman.mdx" ]] && [[ -f "$OCTOPUS_DIR/docs/site/pt-br/commands/steelman.mdx" ]]; }

check "bundle: registered in workflow-extras"    t_bundle
check "docs: EN + pt-br skill pages exist"       t_docs_skill
check "docs: EN + pt-br command pages exist"     t_docs_cmd

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
