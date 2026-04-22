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
check "money-review has pre_pass:" \
  grep -q "^pre_pass:" "$OCTOPUS_DIR/skills/money-review/SKILL.md"
check "security-scan has pre_pass:" \
  grep -q "^pre_pass:" "$OCTOPUS_DIR/skills/security-scan/SKILL.md"
check "cross-stack-contract has pre_pass:" \
  grep -q "^pre_pass:" "$OCTOPUS_DIR/skills/cross-stack-contract/SKILL.md"
check "tenant-scope-audit has pre_pass:" \
  grep -q "^pre_pass:" "$OCTOPUS_DIR/skills/tenant-scope-audit/SKILL.md"

# T5: security-scan file_patterns contains .env
check "security-scan file_patterns contains .env" \
  grep -A2 "file_patterns:" "$OCTOPUS_DIR/skills/security-scan/SKILL.md" | grep -q "env"

# T6: each skill references audit-pre-pass.md in its discovery section
check "money-review references audit-pre-pass.md" \
  grep -q "audit-pre-pass.md" "$OCTOPUS_DIR/skills/money-review/SKILL.md"
check "security-scan references audit-pre-pass.md" \
  grep -q "audit-pre-pass.md" "$OCTOPUS_DIR/skills/security-scan/SKILL.md"
check "cross-stack-contract references audit-pre-pass.md" \
  grep -q "audit-pre-pass.md" "$OCTOPUS_DIR/skills/cross-stack-contract/SKILL.md"
check "tenant-scope-audit references audit-pre-pass.md" \
  grep -q "audit-pre-pass.md" "$OCTOPUS_DIR/skills/tenant-scope-audit/SKILL.md"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
