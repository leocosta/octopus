#!/usr/bin/env bash
# tests/test_pre_llm_audit_pass.sh
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# T1: shared fragment exists
check "shared fragment exists" \
  test -f "$OCTOPUS_DIR/skills/_shared/audit-pre-pass.md"

# T2: fragment contains all 4 step markers
check "fragment contains Step 1" \
  grep -q "Step 1" "$OCTOPUS_DIR/skills/_shared/audit-pre-pass.md"
check "fragment contains Step 2" \
  grep -q "Step 2" "$OCTOPUS_DIR/skills/_shared/audit-pre-pass.md"
check "fragment contains Step 3" \
  grep -q "Step 3" "$OCTOPUS_DIR/skills/_shared/audit-pre-pass.md"
check "fragment contains Step 4" \
  grep -q "Step 4" "$OCTOPUS_DIR/skills/_shared/audit-pre-pass.md"

# T3: fragment contains key protocol terms
check "fragment contains 'early exit'" \
  grep -qi "early exit" "$OCTOPUS_DIR/skills/_shared/audit-pre-pass.md"
check "fragment contains 'CANDIDATE_FILES'" \
  grep -q "CANDIDATE_FILES" "$OCTOPUS_DIR/skills/_shared/audit-pre-pass.md"

# T4: each skill has pre_pass: in frontmatter
check "audit-money has pre_pass:" \
  grep -q "^pre_pass:" "$OCTOPUS_DIR/skills/audit-money/SKILL.md"
check "audit-security has pre_pass:" \
  grep -q "^pre_pass:" "$OCTOPUS_DIR/skills/audit-security/SKILL.md"
check "review-contracts has pre_pass:" \
  grep -q "^pre_pass:" "$OCTOPUS_DIR/skills/review-contracts/SKILL.md"
check "audit-tenant has pre_pass:" \
  grep -q "^pre_pass:" "$OCTOPUS_DIR/skills/audit-tenant/SKILL.md"

# T5: audit-security file_patterns contains .env
check "audit-security file_patterns contains .env" \
  grep -A2 "file_patterns:" "$OCTOPUS_DIR/skills/audit-security/SKILL.md" | grep -q "env"

# T6: each skill references audit-pre-pass.md in its discovery section
check "audit-money references audit-pre-pass.md" \
  grep -q "audit-pre-pass.md" "$OCTOPUS_DIR/skills/audit-money/SKILL.md"
check "audit-security references audit-pre-pass.md" \
  grep -q "audit-pre-pass.md" "$OCTOPUS_DIR/skills/audit-security/SKILL.md"
check "review-contracts references audit-pre-pass.md" \
  grep -q "audit-pre-pass.md" "$OCTOPUS_DIR/skills/review-contracts/SKILL.md"
check "audit-tenant references audit-pre-pass.md" \
  grep -q "audit-pre-pass.md" "$OCTOPUS_DIR/skills/audit-tenant/SKILL.md"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
