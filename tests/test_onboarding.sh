#!/usr/bin/env bash
# tests/test_onboarding.sh
# Structural tests for the onboarding ramp skill (RM-090).
# Grep-based, per project convention.
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$OCTOPUS_DIR/skills/onboarding/SKILL.md"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# --- the skill ----------------------------------------------------------
check "SKILL.md exists" test -f "$SKILL"
check "declares name onboarding" grep -q "name: onboarding" "$SKILL"
check "has trigger keywords" grep -qiE "onboard|ramp up|getting started|new to this repo" "$SKILL"

# --- up-front area question --------------------------------------------
check "asks the area/stack question up front" grep -qiE "area/stack|what area|which area|stack will you" "$SKILL"

# --- the six-step ramp --------------------------------------------------
check "ramp step: the domain (CONTEXT.md)" grep -q "CONTEXT.md" "$SKILL"
check "ramp step: the decisions (ADRs)" grep -qiE "docs/adr|ADR" "$SKILL"
check "ramp step: the standards (rules/)" grep -qE "rules/" "$SKILL"
check "ramp step: the map (presents the map-system deck)" grep -qi "map-system" "$SKILL"
check "presents the complete HTML deck" grep -qiE "deck|docs/system-map|complete" "$SKILL"
check "ramp step: the way of working (PR + DoD)" grep -qiE "definition-of-done|definition of done|DoD|PR flow|way of working" "$SKILL"
check "ramp step: the fleet (audit-fleet)" grep -qiE "audit-fleet|fleet|workspace" "$SKILL"

# --- content sources ----------------------------------------------------
check "offers the standards skill" grep -qi "standards" "$SKILL"
check "honors an optional manager seed" grep -q "docs/onboarding/guide.md" "$SKILL"
check "leads with the seed when present" grep -qiE "seed|guide.md.*priorit|priorit.*guide|leads with" "$SKILL"

# --- ephemeral checklist ------------------------------------------------
check "keeps a resumable checklist" grep -qiE "checklist|resum" "$SKILL"
check "checklist lives under .octopus/onboarding (gitignored)" grep -q ".octopus/onboarding" "$SKILL"
check "is ephemeral / nothing committed" grep -qiE "ephemeral|gitignored|nothing.*commit|not commit|never commit" "$SKILL"

# --- anti-patterns ------------------------------------------------------
check "anti-pattern: do not dump the whole repo" grep -qiE "whole repo|dump|scope to" "$SKILL"

# --- bundle registration ------------------------------------------------
check "registered in docs bundle (interim)" grep -q "onboarding" "$OCTOPUS_DIR/bundles/docs.yml"

# --- gitignore for the ephemeral location -------------------------------
check ".octopus/onboarding/ is gitignored" grep -q ".octopus/onboarding" "$OCTOPUS_DIR/.gitignore"

echo "PASS=$PASS FAIL=$FAIL"
test "$FAIL" -eq 0
