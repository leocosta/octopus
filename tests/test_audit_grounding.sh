#!/usr/bin/env bash
# tests/test_audit_grounding.sh
# Structural tests for the audit-grounding skill, its stop-hook trigger,
# bundle registration, and feature doc. Grep-based, per project convention.
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$OCTOPUS_DIR/skills/audit-grounding/SKILL.md"
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
check "declares name audit-grounding" grep -q "name: audit-grounding" "$SKILL"
check "reads the source of truth (CONTEXT.md)" grep -q "CONTEXT.md" "$SKILL"
check "reads the source of truth (docs/adr)" grep -q "docs/adr" "$SKILL"
check "emits invented-convention finding" grep -q "invented-convention" "$SKILL"
check "emits unsupported-domain-fact finding" grep -q "unsupported-domain-fact" "$SKILL"
check "is signal-only (never blocks)" grep -qiE "signal-only|does not block|never block" "$SKILL"

echo "PASS=$PASS FAIL=$FAIL"
test "$FAIL" -eq 0
