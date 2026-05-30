#!/usr/bin/env bash
# tests/test_definition_of_done.sh
# Structural tests for the definition-of-done artifact + skill.
# Grep-based, per project convention.
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$OCTOPUS_DIR/templates/definition-of-done.md"
SKILL="$OCTOPUS_DIR/skills/definition-of-done/SKILL.md"
CODEREVIEW="$OCTOPUS_DIR/commands/codereview.md"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# --- the template -------------------------------------------------------
check "template exists" test -f "$TEMPLATE"
check "template groups items by concern (Tested)" grep -qi "Tested" "$TEMPLATE"
check "template covers Reviewed" grep -qi "Reviewed" "$TEMPLATE"
check "template covers Documented" grep -qi "Documented" "$TEMPLATE"
check "template covers Grounded" grep -qi "Grounded" "$TEMPLATE"
check "template covers Clean" grep -qi "Clean" "$TEMPLATE"
check "each item points at an enforcer" grep -qE "→|rules/|audit-|doc-adr|architect" "$TEMPLATE"

# --- the skill ----------------------------------------------------------
check "SKILL.md exists" test -f "$SKILL"
check "declares name definition-of-done" grep -q "name: definition-of-done" "$SKILL"
check "declares a create/update mode" grep -qiE "create.?(/|or )?update|create mode|update mode" "$SKILL"
check "declares a validate mode" grep -qiE "validate mode|mode: validate|\*\*validate\*\*" "$SKILL"
check "create mode scaffolds from the template" grep -q "templates/definition-of-done.md" "$SKILL"
check "validate reports an unmet verdict" grep -qiE "unmet" "$SKILL"
check "validate reports a not-applicable verdict" grep -qiE "not-applicable|not applicable|n/a" "$SKILL"
check "references testing enforcement" grep -qE "rules/common/testing.md|test-tdd|testing" "$SKILL"
check "references architect role" grep -qi "architect" "$SKILL"
check "references doc-adr" grep -q "doc-adr" "$SKILL"
check "references audit-grounding (Grounded)" grep -q "audit-grounding" "$SKILL"
check "references the audit-* family" grep -qE "audit-money|audit-tenant|audit-\*|audit family" "$SKILL"
check "declares signal-only / does not gate" grep -qiE "signal-only|signal, not|never gate|does not gate|not a gate" "$SKILL"
check "does not reimplement audits (anti-pattern)" grep -qiE "reimplement|restate|re-?state|duplicate" "$SKILL"
check "integrates with codereview" grep -qi "codereview" "$SKILL"
check "no-ops when DoD absent" grep -qiE "no-op|absent|without a|when (the )?DoD (is )?(missing|absent)|suggest creating" "$SKILL"
check "has trigger keywords" grep -qiE "is this done|ready to merge|done criteria|definition of done" "$SKILL"

# --- codereview wiring --------------------------------------------------
check "codereview consults the DoD" grep -qiE "definition-of-done|definition of done|DoD" "$CODEREVIEW"
check "codereview DoD step is additive / no-op when absent" grep -qiE "no-op|when (it |the DoD )?(is )?absent|if (a |the )?DoD exists|skip" "$CODEREVIEW"

# --- bundle registration ------------------------------------------------
check "registered in docs bundle (interim)" grep -q "definition-of-done" "$OCTOPUS_DIR/bundles/docs.yml"

echo "PASS=$PASS FAIL=$FAIL"
test "$FAIL" -eq 0
