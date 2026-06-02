#!/usr/bin/env bash
# tests/test_audit_style.sh
# Structural tests for the audit-style skill, bundle registration, docs
# pages, and roadmap entry. Grep-based, per project convention.
# audit-style has NO Stop hook (skill-only, orchestrated by review flows),
# so — unlike test_audit_grounding — there are no hook assertions here.
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$OCTOPUS_DIR/skills/audit-style/SKILL.md"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# --- Task 1: the skill ---------------------------------------------------
check "SKILL.md exists" test -f "$SKILL"
check "declares name audit-style" grep -q "name: audit-style" "$SKILL"
check "reads the rules (exceptions.md)" grep -q "exceptions.md" "$SKILL"
check "reads the rules (patterns.md)" grep -q "patterns.md" "$SKILL"
check "reads the rules (coding-style.md)" grep -q "coding-style.md" "$SKILL"
check "emits rule-violation finding" grep -q "rule-violation" "$SKILL"
check "emits over-engineering finding" grep -q "over-engineering" "$SKILL"
check "is signal-only (never blocks)" grep -qiE "signal-only|does not block|never block" "$SKILL"
check "has no Stop hook (skill-only)" grep -qi "no Stop hook\|skill-only" "$SKILL"

# --- Task 2: bundle registration ----------------------------------------
QBUNDLE="$OCTOPUS_DIR/bundles/quality.yml"
check "audit-style listed in quality bundle" grep -qE "^ *- audit-style( |$)" "$QBUNDLE"

# --- Task 3: docs/site pages (check-docs completeness gate) -------------
check "EN docs page exists" test -f "$OCTOPUS_DIR/docs/site/skills/audit-style.mdx"
check "pt-br docs page exists" test -f "$OCTOPUS_DIR/docs/site/pt-br/skills/audit-style.mdx"

# --- Task 4: roadmap ----------------------------------------------------
check "roadmap has RM-112" grep -q "RM-112" "$OCTOPUS_DIR/docs/roadmap.md"

echo "PASS=$PASS FAIL=$FAIL"
test "$FAIL" -eq 0
