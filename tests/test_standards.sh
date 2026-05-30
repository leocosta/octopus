#!/usr/bin/env bash
# tests/test_standards.sh
# Structural tests for the standards self-serve lookup skill.
# Grep-based, per project convention.
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$OCTOPUS_DIR/skills/standards/SKILL.md"
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
check "declares name standards" grep -q "name: standards" "$SKILL"
check "reads docs/adr (decisions)" grep -q "docs/adr" "$SKILL"
check "reads rules/ (coding rules)" grep -q "rules/" "$SKILL"
check "reads CONTEXT.md (vocabulary)" grep -q "CONTEXT.md" "$SKILL"
check "reads knowledge/ (facts)" grep -q "knowledge/" "$SKILL"
check "defines a source precedence order" grep -qiE "precedence|in order" "$SKILL"
check "has a not-found path" grep -qiE "not-found|not found|no documented" "$SKILL"
check "routes to authoring when missing (doc-adr)" grep -q "doc-adr" "$SKILL"
check "is read-only, never gates" grep -qiE "read-only|never gate|does not gate|not a gate" "$SKILL"
check "never invents an answer" grep -qiE "never invent|do not invent|not invent" "$SKILL"

# --- bundle registration ------------------------------------------------
check "registered in docs bundle (interim)" grep -q "standards" "$OCTOPUS_DIR/bundles/docs.yml"

echo "PASS=$PASS FAIL=$FAIL"
test "$FAIL" -eq 0
