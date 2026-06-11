#!/usr/bin/env bash
# tests/test_skill_tiering.sh — RM-160: cheap-class non-audit skills declare a
# `model:` tier so they don't run the frontier model when a cheaper one suffices
# (companion to test_model_tiering.sh, which covers the audit-* family).
#
# Tier is honored by cli/control/skill_matcher.py (daemon path) and documents the
# intended tier for any orchestrator that dispatches the skill. Static assertions,
# no LLM — locks the policy as a regression guard.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
check() { local d="$1"; shift; if "$@"; then echo "PASS: $d"; PASS=$((PASS + 1)); else echo "FAIL: $d"; FAIL=$((FAIL + 1)); fi; }
tier_of() { grep -m1 '^model:[[:space:]]' "$DIR/skills/$1/SKILL.md" 2>/dev/null | sed 's/^model:[[:space:]]*//'; }

# Mechanical / narration / deterministic-core-with-thin-LLM → haiku.
HAIKU="knowledge-briefing knowledge-synthesize knowledge-hygiene code-metrics"
# Reasoning over content, but not architecture/code-gen → sonnet (off Opus).
SONNET="compress-skill map-system launch-release scaffold-skill continuous-learning definition-of-done"
# Genuine reasoning / code generation — must NOT be cheap-tiered.
KEEP="debug implement"

t_haiku() {
  local s; for s in $HAIKU; do
    [[ "$(tier_of "$s")" == "haiku" ]] || { echo "    $s != haiku" >&2; return 1; }
  done
}
check "cheap-class skills are haiku ($HAIKU)" t_haiku

t_sonnet() {
  local s; for s in $SONNET; do
    [[ "$(tier_of "$s")" == "sonnet" ]] || { echo "    $s != sonnet" >&2; return 1; }
  done
}
check "reasoning-but-not-Opus skills are sonnet ($SONNET)" t_sonnet

t_keep() {
  local s t; for s in $KEEP; do
    t="$(tier_of "$s")"
    [[ "$t" != "haiku" && "$t" != "sonnet" ]] || { echo "    $s was cheap-tiered ($t) — needs Opus-class reasoning" >&2; return 1; }
  done
}
check "reasoning/code-gen skills stay Opus-class ($KEEP)" t_keep

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
